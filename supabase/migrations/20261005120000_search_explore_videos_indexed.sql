-- Index-friendly Explore search.
--
-- The previous version matched `title ilike … or username ilike …` across a
-- join, which prevents either trigram index from being used, so every search
-- scanned all videos. Title and username matches are now found separately
-- (via sport_videos_title_trgm_idx and user_personal_profiles_username_trgm_idx)
-- and merged. Ranking, ordering, paging and the returned columns are unchanged.

create or replace function public.search_explore_videos(
  p_query text,
  p_sport_id text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table(
  id uuid,
  user_id uuid,
  user_video_id uuid,
  sport_id text,
  subcategory_id bigint,
  title text,
  description text,
  video_path text,
  thumbnail_path text,
  view_count integer,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  total_ratings integer,
  average_rating numeric,
  bayesian_score numeric,
  username text,
  match_rank integer,
  total_count bigint
)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_sport_id text := nullif(btrim(coalesce(p_sport_id, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 20), 0), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  -- Match user input literally: % and _ would otherwise act as wildcards.
  v_escaped text := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_');
  v_contains text := '%' || v_escaped || '%';
  v_prefix text := v_escaped || '%';
begin
  if v_query = '' and v_sport_id is null then
    return;
  end if;

  return query
  with
  title_hits as (
    select
      sv.id as video_id,
      case
        when lower(sv.title) = lower(v_query) then 1
        when sv.title ilike v_prefix then 2
        else 3
      end as rank
    from public.sport_videos sv
    where v_query <> ''
      and sv.title ilike v_contains
      and (v_sport_id is null or sv.sport_id = v_sport_id)
  ),
  username_hits as (
    select
      sv.id as video_id,
      case when upp.username ilike v_prefix then 4 else 5 end as rank
    from public.user_personal_profiles upp
    join public.sport_videos sv on sv.user_id = upp.id
    where v_query <> ''
      and upp.username ilike v_contains
      and (v_sport_id is null or sv.sport_id = v_sport_id)
  ),
  sport_rows as (
    select sv.id as video_id, 6 as rank
    from public.sport_videos sv
    where v_query = ''
      and sv.sport_id = v_sport_id
  ),
  matches as (
    -- A video matching on both title and username keeps its best (lowest) rank.
    select h.video_id, min(h.rank) as rank
    from (
      select t.video_id, t.rank from title_hits t
      union all
      select u.video_id, u.rank from username_hits u
      union all
      select s.video_id, s.rank from sport_rows s
    ) h
    group by h.video_id
  ),
  counted as (
    select m.video_id, m.rank, count(*) over () as match_count
    from matches m
  )
  select
    sv.id,
    sv.user_id,
    sv.user_video_id,
    sv.sport_id,
    sv.subcategory_id,
    sv.title,
    sv.description,
    sv.video_path,
    sv.thumbnail_path,
    sv.view_count,
    sv.created_at,
    sv.updated_at,
    sv.total_ratings,
    sv.average_rating,
    sv.bayesian_score,
    upp.username,
    c.rank,
    c.match_count
  from counted c
  join public.sport_videos sv on sv.id = c.video_id
  join public.user_personal_profiles upp on upp.id = sv.user_id
  order by
    c.rank asc,
    sv.bayesian_score desc nulls last,
    sv.total_ratings desc nulls last,
    sv.created_at desc nulls last,
    sv.id asc
  limit v_limit
  offset v_offset;
end;
$$;
