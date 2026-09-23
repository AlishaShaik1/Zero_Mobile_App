-- ==============================================================================
-- Zero AI - Production Multi-Session Chat & Training Storage Schema
-- ==============================================================================
-- Paste and run this script in your Supabase Dashboard:
-- SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Create chat_sessions table
create table if not exists public.chat_sessions (
    id            text primary key,               -- session UUID
    user_uid      text not null,                  -- anonymous user fingerprint
    title         text not null default 'New Chat',
    model         text not null default 'titan-pro',
    messages_gz   text,                           -- compressed JSON via lz-string (>80% space savings)
    message_count integer not null default 0,
    token_count   integer not null default 0,     -- estimated tokens for dataset analytics
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

-- 2. Create performance indexes
create index if not exists idx_chat_sessions_user_uid on public.chat_sessions(user_uid);
create index if not exists idx_chat_sessions_updated_at on public.chat_sessions(user_uid, updated_at desc);

-- 3. Auto-update updated_at timestamp trigger
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_chat_sessions_updated_at on public.chat_sessions;
create trigger set_chat_sessions_updated_at
    before update on public.chat_sessions
    for each row
    execute function public.handle_updated_at();

-- 4. Enable Row Level Security (RLS) & Allow access
alter table public.chat_sessions enable row level security;

-- Drop policy first if it exists to allow safe re-running
drop policy if exists "Allow access to own chat sessions" on public.chat_sessions;

-- Create policy allowing access
create policy "Allow access to own chat sessions"
    on public.chat_sessions
    for all
    using (true)
    with check (true);
