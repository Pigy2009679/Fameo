-- FAMEO feature upgrade: notifications + realtime publication
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null check (kind in ('fan','reaction','reply','message_request')),
  note_id uuid references public.notes(id) on delete cascade,
  request_id uuid references public.message_requests(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "users read own notifications" on public.notifications;
create policy "users read own notifications" on public.notifications for select using (auth.uid() = user_id);
drop policy if exists "users mark own notifications" on public.notifications;
create policy "users mark own notifications" on public.notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.fameo_notify() returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid; actor uuid; k text; nid uuid; rid uuid;
begin
  if tg_table_name = 'follows' then target := new.creator_id; actor := new.fan_id; k := 'fan';
  elsif tg_table_name = 'reactions' then select author_id into target from public.notes where id = new.note_id; actor := new.user_id; k := 'reaction'; nid := new.note_id;
  elsif tg_table_name = 'replies' then select author_id into target from public.notes where id = new.note_id; actor := new.author_id; k := 'reply'; nid := new.note_id;
  elsif tg_table_name = 'message_requests' then target := new.recipient_id; actor := new.sender_id; k := 'message_request'; rid := new.id;
  end if;
  if target is not null and actor is distinct from target then
    insert into public.notifications(user_id, actor_id, kind, note_id, request_id) values(target, actor, k, nid, rid);
  end if;
  return new;
end $$;

drop trigger if exists fameo_follow_notification on public.follows;
create trigger fameo_follow_notification after insert on public.follows for each row execute function public.fameo_notify();
drop trigger if exists fameo_reaction_notification on public.reactions;
create trigger fameo_reaction_notification after insert on public.reactions for each row execute function public.fameo_notify();
drop trigger if exists fameo_reply_notification on public.replies;
create trigger fameo_reply_notification after insert on public.replies for each row execute function public.fameo_notify();
drop trigger if exists fameo_request_notification on public.message_requests;
create trigger fameo_request_notification after insert on public.message_requests for each row execute function public.fameo_notify();

-- Enable Supabase Realtime for the app's live feed and inbox.
do $$ begin
  alter publication supabase_realtime add table public.notes;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.reactions;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.replies;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- Prevent duplicate pending requests between the same two accounts.
create unique index if not exists message_requests_one_pending_pair
on public.message_requests(sender_id, recipient_id) where status = 'pending';
