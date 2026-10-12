-- Keyset-paginated Home feed.
--
-- Every video belongs to exactly one source (checked in this order):
--   personalized : subcategory is in the session's tracked subcategories
--   following    : uploaded by a creator the caller follows
--   trending     : created on/after the session's window start (7 days)
--   discovery    : everything else
-- Because sources never overlap, each source pages independently with a
-- keyset position and the client no longer sends a growing seen-ID list.
--
-- `get_home_feed_page` (seen-ID version) is intentionally kept so app builds
-- already in the stores keep working. Drop it once those builds are retired.

-- Indexes -------------------------------------------------------------------

create index if not exists idx_sport_videos_subcategory_score_id
  on public.sport_videos (
    subcategory_id,
    (coalesce(bayesian_score, 0)::numeric) desc,
    id desc
  );

create index if not exists idx_sport_videos_created_id
  on public.sport_videos (created_at desc, id desc);

-- Duplicates or prefixes of other indexes; they only add write cost.
drop index if exists public.sport_videos_user_id_idx;               -- = idx_sport_videos_user_id
drop index if exists public.idx_sport_videos_category;              -- prefix of idx_sport_videos_ranking
drop index if exists public.sport_videos_sport_id_idx;              -- prefix of idx_sport_videos_ranking
drop index if exists public.idx_sport_videos_created;               -- prefix of idx_sport_videos_created_id
drop index if exists public.user_follows_follower_id_followed_user_id_idx; -- = unique constraint index

-- Function ------------------------------------------------------------------

create or replace function public.get_home_feed_page_v2(
  p_limit integer default 24,
  p_tracked_subcategory_ids bigint[] default '{}',
  p_cursor jsonb default '{}'
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 24), 1), 100);
  v_cursor jsonb := coalesce(p_cursor, '{}'::jsonb);
  v_tracked bigint[];
  v_window_start timestamptz;

  v_has_p boolean := coalesce((v_cursor ->> 'hasMorePersonalized')::boolean, true);
  v_has_f boolean := coalesce((v_cursor ->> 'hasMoreFollowing')::boolean, true);
  v_has_t boolean := coalesce((v_cursor ->> 'hasMoreTrending')::boolean, true);
  v_has_d boolean := coalesce((v_cursor ->> 'hasMoreDiscovery')::boolean, true);

  -- Sentinels sort before every real row, so the first page needs no special case.
  -- bayesian_score is numeric(4,2), so 1000 is above any real score.
  v_max_id constant uuid := 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  v_max_score constant numeric := 1000;
  v_p_score numeric := coalesce((v_cursor #>> '{personalized,score}')::numeric, v_max_score);
  v_p_id uuid := coalesce((v_cursor #>> '{personalized,id}')::uuid, v_max_id);
  v_f_created timestamptz := coalesce((v_cursor #>> '{following,createdAt}')::timestamptz, 'infinity'::timestamptz);
  v_f_id uuid := coalesce((v_cursor #>> '{following,id}')::uuid, v_max_id);
  v_t_score numeric := coalesce((v_cursor #>> '{trending,score}')::numeric, v_max_score);
  v_t_id uuid := coalesce((v_cursor #>> '{trending,id}')::uuid, v_max_id);
  v_d_created timestamptz := coalesce((v_cursor #>> '{discovery,createdAt}')::timestamptz, 'infinity'::timestamptz);
  v_d_id uuid := coalesce((v_cursor #>> '{discovery,id}')::uuid, v_max_id);
begin
  -- Tracked subcategories and the trending window are frozen for the session
  -- so a video can't move between sources mid-scroll.
  if jsonb_typeof(v_cursor -> 'trackedSubcategoryIds') = 'array' then
    v_tracked := array(
      select jsonb_array_elements_text(v_cursor -> 'trackedSubcategoryIds')::bigint
    );
  else
    v_tracked := array_remove(coalesce(p_tracked_subcategory_ids, '{}'::bigint[]), null);
  end if;

  v_window_start := coalesce(
    (v_cursor ->> 'windowStart')::timestamptz,
    now() - interval '7 days'
  );

  return (
    with
    targets as (
      select
        t.source,
        t.source_order,
        t.weight,
        floor(v_limit * t.weight)::integer
          + case
              when row_number() over (
                order by v_limit * t.weight - floor(v_limit * t.weight) desc, t.weight desc
              ) <= v_limit - sum(floor(v_limit * t.weight)::integer) over ()
              then 1
              else 0
            end as target_count
      from (values
        ('personalized'::text, 0, 0.40::numeric),
        ('following'::text, 1, 0.30::numeric),
        ('trending'::text, 2, 0.20::numeric),
        ('discovery'::text, 3, 0.10::numeric)
      ) as t(source, source_order, weight)
    ),
    personalized as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'personalized'::text as source,
        0 as source_order,
        row_number() over (
          order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
        ) as source_rank
      from public.sport_videos sv
      where v_has_p
        and sv.subcategory_id = any(v_tracked)
        and (coalesce(sv.bayesian_score, 0)::numeric, sv.id) < (v_p_score, v_p_id)
      order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
      limit v_limit + 1
    ),
    following as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'following'::text as source,
        1 as source_order,
        row_number() over (order by sv.created_at desc, sv.id desc) as source_rank
      from public.sport_videos sv
      where v_has_f
        and v_user_id is not null
        and sv.user_id in (
          select uf.followed_user_id
          from public.user_follows uf
          where uf.follower_id = v_user_id
        )
        and not (sv.subcategory_id = any(v_tracked))
        and (sv.created_at, sv.id) < (v_f_created, v_f_id)
      order by sv.created_at desc, sv.id desc
      limit v_limit + 1
    ),
    trending as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'trending'::text as source,
        2 as source_order,
        row_number() over (
          order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
        ) as source_rank
      from public.sport_videos sv
      where v_has_t
        and sv.created_at >= v_window_start
        and not (sv.subcategory_id = any(v_tracked))
        and not exists (
          select 1
          from public.user_follows uf
          where uf.follower_id = v_user_id
            and uf.followed_user_id = sv.user_id
        )
        and (coalesce(sv.bayesian_score, 0)::numeric, sv.id) < (v_t_score, v_t_id)
      order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
      limit v_limit + 1
    ),
    discovery as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'discovery'::text as source,
        3 as source_order,
        row_number() over (order by sv.created_at desc, sv.id desc) as source_rank
      from public.sport_videos sv
      where v_has_d
        and sv.created_at < v_window_start
        and not (sv.subcategory_id = any(v_tracked))
        and not exists (
          select 1
          from public.user_follows uf
          where uf.follower_id = v_user_id
            and uf.followed_user_id = sv.user_id
        )
        and (sv.created_at, sv.id) < (v_d_created, v_d_id)
      order by sv.created_at desc, sv.id desc
      limit v_limit + 1
    ),
    candidates as (
      select * from personalized
      union all select * from following
      union all select * from trending
      union all select * from discovery
    ),
    -- Fill each source's share first, then backfill round-robin. Either way a
    -- source only ever delivers a prefix of its ordering, so its cursor stays valid.
    picked as (
      select c.*, t.weight
      from candidates c
      join targets t on t.source = c.source
      order by greatest(c.source_rank - t.target_count, 0), c.source_order, c.source_rank
      limit v_limit
    ),
    last_picked as (
      select distinct on (p.source) p.source, p.id, p.sort_score, p.created_at
      from picked p
      order by p.source, p.source_rank desc
    ),
    stats as (
      select
        t.source,
        (select count(*) from candidates c where c.source = t.source)
          > (select count(*) from picked p where p.source = t.source) as has_more,
        case
          when lp.id is null then v_cursor -> t.source
          -- Score as text: a JSON number can lose precision in the app and break the keyset.
          when t.source in ('personalized', 'trending')
            then jsonb_build_object('score', lp.sort_score::text, 'id', lp.id)
          else jsonb_build_object('createdAt', lp.created_at, 'id', lp.id)
        end as next_position
      from targets t
      left join last_picked lp on lp.source = t.source
    )
    select jsonb_build_object(
      'videos',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', sv.id,
              'user_id', sv.user_id,
              'user_video_id', sv.user_video_id,
              'sport_id', sv.sport_id,
              'subcategory_id', sv.subcategory_id,
              'title', sv.title,
              'description', sv.description,
              'video_path', sv.video_path,
              'thumbnail_path', sv.thumbnail_path,
              'view_count', sv.view_count,
              'created_at', sv.created_at,
              'updated_at', sv.updated_at,
              'total_ratings', sv.total_ratings,
              'average_rating', sv.average_rating,
              'bayesian_score', sv.bayesian_score,
              'username', upp.username,
              'source', p.source
            )
            -- Weighted interleave: P, F, P, T, P, F, D, ...
            order by p.source_rank / p.weight, p.source_order
          )
          from picked p
          join public.sport_videos sv on sv.id = p.id
          left join public.user_personal_profiles upp on upp.id = sv.user_id
        ),
        '[]'::jsonb
      ),
      'nextCursor',
      jsonb_build_object(
        'pagination', 'keyset',
        'windowStart', v_window_start,
        'trackedSubcategoryIds', to_jsonb(v_tracked)
      )
      || (select jsonb_object_agg(s.source, s.next_position) from stats s)
      || (select jsonb_object_agg('hasMore' || initcap(s.source), s.has_more) from stats s),
      'hasMoreContent', exists (select 1 from stats s where s.has_more)
    )
  );
end;
$$;

grant execute on function public.get_home_feed_page_v2(integer, bigint[], jsonb)
  to anon, authenticated;
