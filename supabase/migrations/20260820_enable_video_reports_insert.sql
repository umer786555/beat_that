grant insert on table public.video_reports to authenticated;

alter table public.video_reports enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'video_reports'
      and policyname = 'authenticated_users_can_insert_own_video_reports'
  ) then
    create policy authenticated_users_can_insert_own_video_reports
      on public.video_reports
      for insert
      to authenticated
      with check (reported_by = auth.uid());
  end if;
end
$$;