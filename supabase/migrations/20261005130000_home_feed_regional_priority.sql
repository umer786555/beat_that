-- Regional priority for the Home feed.
--
-- Regions: west (Europe, Turkey, Americas, Australia/NZ, Russia), africa, asia (everything
-- else, incl. the Middle East). Each feed source is split into a local half
-- (same region as the viewer) and a global half, weighted 70/30.
--
-- Country comes only from the caller's IP (Cloudflare `cf-ipcountry`). Viewers
-- with an unknown country get the west feed; videos with one are global.

-- Request country -------------------------------------------------------------

create or replace function public.request_country_code()
returns text
language sql
stable
set search_path = ''
as $$
  select case
    -- Cloudflare: XX = unknown, T1 = Tor.
    when c.code in ('XX', 'T1') then null
    else c.code
  end
  from (
    select nullif(
      upper(btrim(
        -- Pooled connections can hold '' instead of NULL outside a PostgREST request.
        nullif(current_setting('request.headers', true), '')::json ->> 'cf-ipcountry'
      )),
      ''
    ) as code
  ) c;
$$;

grant execute on function public.request_country_code() to anon, authenticated;

-- Uploads are inserted directly by the app, so the header is the uploader's.
-- Any value sent by the app is ignored.
create or replace function public.my_videos_set_country_code()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.country_code := public.request_country_code();
  return new;
end;
$$;

drop trigger if exists my_videos_set_country_code on public.my_videos;
create trigger my_videos_set_country_code
  before insert on public.my_videos
  for each row
  execute function public.my_videos_set_country_code();

-- Region mapping --------------------------------------------------------------

create or replace function public.region_for_country(p_country_code text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when nullif(btrim(p_country_code), '') is null then null
    when upper(btrim(p_country_code)) in (
      -- Europe + Russia + Turkey
      'AD','AL','AT','AX','BA','BE','BG','BY','CH','CY','CZ','DE','DK','EE','ES',
      'FI','FO','FR','GB','GG','GI','GR','HR','HU','IE','IM','IS','IT','JE','LI',
      'LT','LU','LV','MC','MD','ME','MK','MT','NL','NO','PL','PT','RO','RS','RU',
      'SE','SI','SJ','SK','SM','TR','UA','VA','XK',
      -- North + Central America, Caribbean
      'US','CA','MX','GT','BZ','SV','HN','NI','CR','PA','AG','AI','AW','BB','BL',
      'BM','BQ','BS','CU','CW','DM','DO','GD','GL','GP','HT','JM','KN','KY','LC',
      'MF','MQ','MS','PM','PR','SX','TC','TT','VC','VG','VI','UM',
      -- South America
      'AR','BO','BR','CL','CO','EC','FK','GF','GS','GY','PE','PY','SR','UY','VE',
      -- Oceania
      'AU','NZ'
    ) then 'west'
    when upper(btrim(p_country_code)) in (
      'DZ','AO','BJ','BW','BF','BI','CV','CM','CF','TD','KM','CG','CD','CI','DJ',
      'EG','GQ','ER','SZ','ET','GA','GM','GH','GN','GW','KE','LS','LR','LY','MG',
      'MW','ML','MR','MU','YT','MA','MZ','NA','NE','NG','RE','RW','SH','ST','SN',
      'SC','SL','SO','ZA','SS','SD','TZ','TG','TN','UG','EH','ZM','ZW'
    ) then 'africa'
    -- Anything that isn't a two-letter country code is treated as unknown.
    when upper(btrim(p_country_code)) ~ '^[A-Z]{2}$' then 'asia'
    else null
  end;
$$;

grant execute on function public.region_for_country(text) to anon, authenticated;

-- Stored so the moderation edge function needs no changes.
alter table public.sport_videos
  add column if not exists region text
  generated always as (public.region_for_country(country_code)) stored;

-- Indexes -------------------------------------------------------------------

create index if not exists idx_sport_videos_region_subcategory_score_id
  on public.sport_videos (
    region,
    subcategory_id,
    (coalesce(bayesian_score, 0)::numeric) desc,
    id desc
  );

create index if not exists idx_sport_videos_region_created_id
  on public.sport_videos (region, created_at desc, id desc);

-- Function ------------------------------------------------------------------

drop function if exists public.get_home_feed_page_v2(integer, bigint[], jsonb, text);
drop function if exists public.get_home_feed_page_v2(integer, bigint[], jsonb);

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
  v_has jsonb := coalesce(v_cursor -> 'hasMore', '{}'::jsonb);
  v_tracked bigint[];
  v_window_start timestamptz;
  v_region text;

  -- Sentinels sort before every real row, so the first page needs no special case.
  -- bayesian_score is numeric(4,2), so 1000 is above any real score.
  v_max_id constant uuid := 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  v_max_score constant numeric := 1000;
  v_max_created constant timestamptz := 'infinity';

  v_pl_score numeric := coalesce((v_cursor #>> '{personalized_local,score}')::numeric, v_max_score);
  v_pl_id uuid := coalesce((v_cursor #>> '{personalized_local,id}')::uuid, v_max_id);
  v_pg_score numeric := coalesce((v_cursor #>> '{personalized_global,score}')::numeric, v_max_score);
  v_pg_id uuid := coalesce((v_cursor #>> '{personalized_global,id}')::uuid, v_max_id);
  v_fl_created timestamptz := coalesce((v_cursor #>> '{following_local,createdAt}')::timestamptz, v_max_created);
  v_fl_id uuid := coalesce((v_cursor #>> '{following_local,id}')::uuid, v_max_id);
  v_fg_created timestamptz := coalesce((v_cursor #>> '{following_global,createdAt}')::timestamptz, v_max_created);
  v_fg_id uuid := coalesce((v_cursor #>> '{following_global,id}')::uuid, v_max_id);
  v_tl_score numeric := coalesce((v_cursor #>> '{trending_local,score}')::numeric, v_max_score);
  v_tl_id uuid := coalesce((v_cursor #>> '{trending_local,id}')::uuid, v_max_id);
  v_tg_score numeric := coalesce((v_cursor #>> '{trending_global,score}')::numeric, v_max_score);
  v_tg_id uuid := coalesce((v_cursor #>> '{trending_global,id}')::uuid, v_max_id);
  v_dl_created timestamptz := coalesce((v_cursor #>> '{discovery_local,createdAt}')::timestamptz, v_max_created);
  v_dl_id uuid := coalesce((v_cursor #>> '{discovery_local,id}')::uuid, v_max_id);
  v_dg_created timestamptz := coalesce((v_cursor #>> '{discovery_global,createdAt}')::timestamptz, v_max_created);
  v_dg_id uuid := coalesce((v_cursor #>> '{discovery_global,id}')::uuid, v_max_id);
begin
  -- Tracked subcategories, trending window and region are frozen for the
  -- session so a video can't move between sources mid-scroll.
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

  if v_cursor ? 'region' then
    v_region := v_cursor ->> 'region';
  else
    v_region := coalesce(
      public.region_for_country(public.request_country_code()),
      'west'
    );
  end if;

  return (
    with
    weights as (
      select
        g.grp || '_' || s.scope as source,
        g.grp_order * 2 + s.scope_order as source_order,
        g.weight * s.share as weight
      from (values
        ('personalized'::text, 0, 0.40::numeric),
        ('following'::text, 1, 0.30::numeric),
        ('trending'::text, 2, 0.20::numeric),
        ('discovery'::text, 3, 0.10::numeric)
      ) as g(grp, grp_order, weight)
      cross join (values
        ('local'::text, 0, 0.70::numeric),
        ('global'::text, 1, 0.30::numeric)
      ) as s(scope, scope_order, share)
    ),
    targets as (
      select
        w.source,
        w.source_order,
        w.weight,
        floor(v_limit * w.weight)::integer
          + case
              when row_number() over (
                order by v_limit * w.weight - floor(v_limit * w.weight) desc, w.weight desc
              ) <= v_limit - sum(floor(v_limit * w.weight)::integer) over ()
              then 1
              else 0
            end as target_count
      from weights w
    ),
    personalized_local as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'personalized_local'::text as source,
        row_number() over (
          order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
        ) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'personalized_local')::boolean, true)
        and sv.region = v_region
        and sv.subcategory_id = any(v_tracked)
        and (coalesce(sv.bayesian_score, 0)::numeric, sv.id) < (v_pl_score, v_pl_id)
      order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
      limit v_limit + 1
    ),
    personalized_global as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'personalized_global'::text as source,
        row_number() over (
          order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
        ) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'personalized_global')::boolean, true)
        and sv.region is distinct from v_region
        and sv.subcategory_id = any(v_tracked)
        and (coalesce(sv.bayesian_score, 0)::numeric, sv.id) < (v_pg_score, v_pg_id)
      order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
      limit v_limit + 1
    ),
    following_local as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'following_local'::text as source,
        row_number() over (order by sv.created_at desc, sv.id desc) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'following_local')::boolean, true)
        and v_user_id is not null
        and sv.region = v_region
        and sv.user_id in (
          select uf.followed_user_id
          from public.user_follows uf
          where uf.follower_id = v_user_id
        )
        and not (sv.subcategory_id = any(v_tracked))
        and (sv.created_at, sv.id) < (v_fl_created, v_fl_id)
      order by sv.created_at desc, sv.id desc
      limit v_limit + 1
    ),
    following_global as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'following_global'::text as source,
        row_number() over (order by sv.created_at desc, sv.id desc) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'following_global')::boolean, true)
        and v_user_id is not null
        and sv.region is distinct from v_region
        and sv.user_id in (
          select uf.followed_user_id
          from public.user_follows uf
          where uf.follower_id = v_user_id
        )
        and not (sv.subcategory_id = any(v_tracked))
        and (sv.created_at, sv.id) < (v_fg_created, v_fg_id)
      order by sv.created_at desc, sv.id desc
      limit v_limit + 1
    ),
    trending_local as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'trending_local'::text as source,
        row_number() over (
          order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
        ) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'trending_local')::boolean, true)
        and sv.region = v_region
        and sv.created_at >= v_window_start
        and not (sv.subcategory_id = any(v_tracked))
        and not exists (
          select 1
          from public.user_follows uf
          where uf.follower_id = v_user_id
            and uf.followed_user_id = sv.user_id
        )
        and (coalesce(sv.bayesian_score, 0)::numeric, sv.id) < (v_tl_score, v_tl_id)
      order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
      limit v_limit + 1
    ),
    trending_global as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'trending_global'::text as source,
        row_number() over (
          order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
        ) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'trending_global')::boolean, true)
        and sv.region is distinct from v_region
        and sv.created_at >= v_window_start
        and not (sv.subcategory_id = any(v_tracked))
        and not exists (
          select 1
          from public.user_follows uf
          where uf.follower_id = v_user_id
            and uf.followed_user_id = sv.user_id
        )
        and (coalesce(sv.bayesian_score, 0)::numeric, sv.id) < (v_tg_score, v_tg_id)
      order by coalesce(sv.bayesian_score, 0)::numeric desc, sv.id desc
      limit v_limit + 1
    ),
    discovery_local as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'discovery_local'::text as source,
        row_number() over (order by sv.created_at desc, sv.id desc) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'discovery_local')::boolean, true)
        and sv.region = v_region
        and sv.created_at < v_window_start
        and not (sv.subcategory_id = any(v_tracked))
        and not exists (
          select 1
          from public.user_follows uf
          where uf.follower_id = v_user_id
            and uf.followed_user_id = sv.user_id
        )
        and (sv.created_at, sv.id) < (v_dl_created, v_dl_id)
      order by sv.created_at desc, sv.id desc
      limit v_limit + 1
    ),
    discovery_global as (
      select
        sv.id,
        coalesce(sv.bayesian_score, 0)::numeric as sort_score,
        sv.created_at,
        'discovery_global'::text as source,
        row_number() over (order by sv.created_at desc, sv.id desc) as source_rank
      from public.sport_videos sv
      where coalesce((v_has ->> 'discovery_global')::boolean, true)
        and sv.region is distinct from v_region
        and sv.created_at < v_window_start
        and not (sv.subcategory_id = any(v_tracked))
        and not exists (
          select 1
          from public.user_follows uf
          where uf.follower_id = v_user_id
            and uf.followed_user_id = sv.user_id
        )
        and (sv.created_at, sv.id) < (v_dg_created, v_dg_id)
      order by sv.created_at desc, sv.id desc
      limit v_limit + 1
    ),
    candidates as (
      select * from personalized_local
      union all select * from personalized_global
      union all select * from following_local
      union all select * from following_global
      union all select * from trending_local
      union all select * from trending_global
      union all select * from discovery_local
      union all select * from discovery_global
    ),
    -- Fill each source's share first, then backfill round-robin. Either way a
    -- source only ever delivers a prefix of its ordering, so its cursor stays valid.
    picked as (
      select c.*, t.weight, t.source_order
      from candidates c
      join targets t on t.source = c.source
      order by greatest(c.source_rank - t.target_count, 0), t.source_order, c.source_rank
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
        split_part(t.source, '_', 1) as grp,
        (select count(*) from candidates c where c.source = t.source)
          > (select count(*) from picked p where p.source = t.source) as has_more,
        case
          when lp.id is null then v_cursor -> t.source
          -- Score as text: a JSON number can lose precision in the app and break the keyset.
          when split_part(t.source, '_', 1) in ('personalized', 'trending')
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
              'source', split_part(p.source, '_', 1)
            )
            -- Weighted interleave across all 8 sub-sources.
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
        'trackedSubcategoryIds', to_jsonb(v_tracked),
        'region', v_region,
        'hasMore', (select jsonb_object_agg(s.source, s.has_more) from stats s)
      )
      || (select jsonb_object_agg(s.source, s.next_position) from stats s)
      -- Per-group flags read by the app's HomeFeedCursor.
      || (
        select jsonb_object_agg('hasMore' || initcap(g.grp), g.has_more)
        from (
          select s.grp, bool_or(s.has_more) as has_more
          from stats s
          group by s.grp
        ) g
      ),
      'hasMoreContent', exists (select 1 from stats s where s.has_more)
    )
  );
end;
$$;

grant execute on function public.get_home_feed_page_v2(integer, bigint[], jsonb)
  to anon, authenticated;
