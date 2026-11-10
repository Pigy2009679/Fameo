-- FAMEO starter database schema (Supabase / PostgreSQL)
-- Run in a NEW Supabase project's SQL Editor after enabling Auth.
-- Location and school/workplace are deliberately not stored in this starter schema.

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  bio text not null default '' check (char_length(bio) <= 160),
  show_in_leaderboards boolean not null default false,
  allow_message_requests boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 280),
  created_at timestamptz not null default now()
);
create index notes_author_created_idx on public.notes(author_id, created_at desc);

create table public.follows (
  fan_id uuid not null references public.profiles(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (fan_id, creator_id),
  check (fan_id <> creator_id)
);

create table public.reactions (
  note_id uuid not null references public.notes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (note_id, user_id)
);

create table public.replies (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 180),
  created_at timestamptz not null default now()
);
create index replies_note_created_idx on public.replies(note_id, created_at);

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_one uuid not null references public.profiles(id) on delete cascade,
  user_two uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_one < user_two),
  unique (user_one, user_two)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index messages_conversation_created_idx on public.messages(conversation_id, created_at);

create table public.message_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  first_message text not null check (char_length(first_message) between 1 and 2000),
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  note_id uuid references public.notes(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reason text not null check (char_length(reason) between 3 and 500),
  created_at timestamptz not null default now(),
  check (reported_user_id is not null or note_id is not null or message_id is not null)
);

alter table public.profiles enable row level security;
alter table public.notes enable row level security;
alter table public.follows enable row level security;
alter table public.reactions enable row level security;
alter table public.replies enable row level security;
alter table public.blocks enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.message_requests enable row level security;
alter table public.reports enable row level security;

-- Public profile fields are readable; only the owner can edit their profile.
create policy "profiles readable" on public.profiles for select using (true);
create policy "profile owner inserts" on public.profiles for insert with check (auth.uid() = id);
create policy "profile owner updates" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "notes readable" on public.notes for select using (true);
create policy "users create own notes" on public.notes for insert with check (auth.uid() = author_id);
create policy "authors edit own notes" on public.notes for update using (auth.uid() = author_id) with check (auth.uid() = author_id);
create policy "authors delete own notes" on public.notes for delete using (auth.uid() = author_id);

create policy "follows readable" on public.follows for select using (true);
create policy "users follow as themselves" on public.follows for insert with check (auth.uid() = fan_id);
create policy "users unfollow themselves" on public.follows for delete using (auth.uid() = fan_id);

create policy "reactions readable" on public.reactions for select using (true);
create policy "users react as themselves" on public.reactions for insert with check (auth.uid() = user_id);
create policy "users remove own reactions" on public.reactions for delete using (auth.uid() = user_id);

create policy "replies readable" on public.replies for select using (true);
create policy "users add own replies" on public.replies for insert with check (auth.uid() = author_id);
create policy "authors delete own replies" on public.replies for delete using (auth.uid() = author_id);

create policy "users read own blocks" on public.blocks for select using (auth.uid() = blocker_id);
create policy "users create own blocks" on public.blocks for insert with check (auth.uid() = blocker_id);
create policy "users remove own blocks" on public.blocks for delete using (auth.uid() = blocker_id);

-- Conversation membership is required to view or send messages.
create policy "participants read conversations" on public.conversations for select using (auth.uid() = user_one or auth.uid() = user_two);
create policy "participants create conversations" on public.conversations for insert with check (auth.uid() = user_one or auth.uid() = user_two);
create policy "participants read messages" on public.messages for select using (
  auth.uid() = sender_id and exists (select 1 from public.conversations c where c.id = conversation_id and (c.user_one = auth.uid() or c.user_two = auth.uid()))
  or exists (select 1 from public.conversations c where c.id = conversation_id and (c.user_one = auth.uid() or c.user_two = auth.uid()))
);
create policy "participants send messages" on public.messages for insert with check (
  auth.uid() = sender_id and exists (select 1 from public.conversations c where c.id = conversation_id and (c.user_one = auth.uid() or c.user_two = auth.uid()))
);

create policy "users see requests sent or received" on public.message_requests for select using (auth.uid() = sender_id or auth.uid() = recipient_id);
create policy "users send own requests" on public.message_requests for insert with check (auth.uid() = sender_id);
create policy "recipients update requests" on public.message_requests for update using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);

-- Reports are private to the reporting user; production moderation should also use a trusted server workflow.
create policy "reporters submit reports" on public.reports for insert with check (auth.uid() = reporter_id);
create policy "reporters see own reports" on public.reports for select using (auth.uid() = reporter_id);

-- IMPORTANT: Before launch, add server-side checks for blocks, message-request acceptance,
-- rate limits, moderation, account deletion, age-appropriate safety, and leaderboard aggregation.
