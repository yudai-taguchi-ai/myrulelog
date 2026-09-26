-- マイルールログのテーブル定義。Supabase MCP の apply_migration で本番に適用済み（2026-09-26）。

-- 設定（1ユーザー1行）
create table public.settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  base_gain integer not null default 20,
  started_at date not null default current_date,
  created_at timestamptz not null default now()
);

-- ルール
create table public.rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  min_points integer not null default -10,
  max_points integer not null default 0,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  check (min_points <= max_points)
);

-- ごほうび
create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  cost integer not null default 10 check (cost >= 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- 日ごとのメモ
create table public.day_notes (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  note text not null default '' check (char_length(note) <= 300),
  updated_at timestamptz not null default now(),
  primary key (user_id, date)
);

-- 記録（1回の記録 = 1行）。ルールを消しても記録は残す
create table public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  rule_id uuid references public.rules(id) on delete set null,
  rule_name text not null,
  points integer not null,
  note text not null default '' check (char_length(note) <= 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index entries_user_date_idx on public.entries (user_id, date);
create index entries_rule_idx on public.entries (rule_id);

-- ごほうび交換の履歴
create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null default current_date,
  reward_id uuid references public.rewards(id) on delete set null,
  reward_name text not null,
  cost integer not null check (cost >= 0),
  redeemed_at timestamptz not null default now()
);
create index redemptions_user_date_idx on public.redemptions (user_id, date);
create index redemptions_reward_idx on public.redemptions (reward_id);
create index rules_user_idx on public.rules (user_id);
create index rewards_user_idx on public.rewards (user_id);

-- RLS: ログインした本人の行だけ読み書きできる
do $$
declare t text;
begin
  foreach t in array array['settings','rules','rewards','day_notes','entries','redemptions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format($p$create policy "own rows only" on public.%I for all to authenticated
      using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)$p$, t);
  end loop;
end $$;
