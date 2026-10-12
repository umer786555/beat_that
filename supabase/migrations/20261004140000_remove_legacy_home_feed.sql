-- No released app builds depend on the legacy feed, so remove it.

-- Legacy Home feed RPCs, replaced by get_home_feed_page_v2.
do $$
declare
  v_fn regprocedure;
begin
  for v_fn in
    select p.oid::regprocedure
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('get_home_feed_page', 'get_following_videos', 'get_discovery_videos')
  loop
    execute format('drop function %s', v_fn);
  end loop;
end;
$$;

-- Clients may only insert content columns; ranking fields use their defaults.
drop trigger if exists sport_videos_reset_server_fields on public.sport_videos;
drop function if exists public.sport_videos_reset_server_fields();

revoke insert on public.sport_videos from anon, authenticated;
grant insert (
  user_id,
  user_video_id,
  sport_id,
  subcategory_id,
  title,
  description,
  video_path,
  thumbnail_path
) on public.sport_videos to authenticated;
