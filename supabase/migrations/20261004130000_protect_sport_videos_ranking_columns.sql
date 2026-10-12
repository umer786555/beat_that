-- Stop clients from setting ranking fields on public.sport_videos.
--
-- Ratings and views are written by SECURITY DEFINER functions
-- (update_video_bayesian_stats, increment_both_view_counts), which run as the
-- table owner and are not affected by the client restrictions below.

-- Updates: owners may only edit display text. Everything else is server-owned.

revoke update on public.sport_videos from anon, authenticated;
grant update (title, description) on public.sport_videos to authenticated;

-- Inserts: column privileges would break app builds that still send
-- created_at/view_count, so overwrite server-owned fields instead.
create or replace function public.sport_videos_reset_server_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    new.created_at := now();
    new.updated_at := now();
    new.view_count := 0;
    -- Matches the column defaults for an unrated video.
    new.total_ratings := 0;
    new.sum_ratings := 0;
    new.average_rating := 0;
    new.bayesian_score := 5.5;
  end if;
  return new;
end;
$$;

drop trigger if exists sport_videos_reset_server_fields on public.sport_videos;
create trigger sport_videos_reset_server_fields
  before insert on public.sport_videos
  for each row
  execute function public.sport_videos_reset_server_fields();

-- Exact duplicates of the user_blocks_unique_pair constraint index.
drop index if exists public.user_blocks_blocker_blocked_idx;
drop index if exists public.idx_user_blocks_blocker_blocked;
