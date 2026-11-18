-- Block: esquema inicial.
--
-- Modelo: una cuenta = un estudiante. Todos los dispositivos con la misma
-- cuenta quedan vinculados. La sesion de concentracion vive en el servidor
-- con una hora de fin absoluta (ends_at) que fija el propio servidor, para
-- que cambiar la hora del movil no sirva para saltarsela.
--
-- El movil consulta el estado desde un AccessibilityService nativo que no
-- comparte el token de usuario de Flutter (dos clientes rotando el mismo
-- refresh token se revocan entre si). Por eso cada dispositivo tiene un
-- secreto propio y unas funciones SECURITY DEFINER que solo aceptan ese par
-- (device_id, secreto).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- tablas

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'windows')),
  name text not null check (char_length(name) between 1 and 80),
  secret_hash text not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index devices_user_idx on public.devices (user_id);

create table public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  started_from_device uuid references public.devices (id) on delete set null,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  single_window boolean not null default false,
  status text not null default 'active'
    check (status in ('active', 'completed', 'emergency_exit')),
  emergency_reason text check (char_length(emergency_reason) <= 200),
  ended_at timestamptz,
  check (ends_at > started_at)
);
create index focus_sessions_user_idx on public.focus_sessions (user_id, started_at desc);

create table public.block_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'windows', 'web')),
  kind text not null check (kind in ('app', 'site')),
  value text not null check (char_length(value) between 1 and 200),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, platform, kind, value)
);

-- ---------------------------------------------------------------- RLS

alter table public.devices enable row level security;
alter table public.focus_sessions enable row level security;
alter table public.block_rules enable row level security;

create policy "devices: own rows" on public.devices
  for select using ((select auth.uid()) = user_id);
create policy "devices: delete own" on public.devices
  for delete using ((select auth.uid()) = user_id);

create policy "sessions: read own" on public.focus_sessions
  for select using ((select auth.uid()) = user_id);

create policy "rules: all own" on public.block_rules
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Las sesiones solo se crean y cierran por RPC: asi el servidor es quien fija
-- las horas y nadie puede crear una sesion "ya terminada" o alargar otra.

-- ---------------------------------------------------------------- helpers

create or replace function public.active_session_for(p_user uuid)
returns public.focus_sessions
language sql stable security definer set search_path = ''
as $$
  select s.* from public.focus_sessions s
  where s.user_id = p_user and s.status = 'active' and s.ends_at > now()
  order by s.started_at desc
  limit 1;
$$;
revoke all on function public.active_session_for(uuid) from public, anon, authenticated;

-- Estado que devuelven todas las RPC: la sesion activa (o nulls) y la hora del
-- servidor, con la que cada cliente calcula su desfase de reloj.
create or replace function public.session_state(p_user uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare s public.focus_sessions;
begin
  s := public.active_session_for(p_user);
  return jsonb_build_object(
    'server_now', now(),
    'session', case when s.id is null then null else jsonb_build_object(
      'id', s.id,
      'started_at', s.started_at,
      'ends_at', s.ends_at,
      'single_window', s.single_window,
      'started_from_device', s.started_from_device
    ) end
  );
end;
$$;
revoke all on function public.session_state(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- RPC usuario

-- Registra este dispositivo y devuelve su id y un secreto que solo se ve una vez.
create or replace function public.register_device(p_platform text, p_name text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_secret text := encode(extensions.gen_random_bytes(32), 'hex');
  v_id uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  insert into public.devices (user_id, platform, name, secret_hash)
  values (v_user, p_platform, left(p_name, 80), encode(extensions.digest(v_secret, 'sha256'), 'hex'))
  returning id into v_id;
  return jsonb_build_object('device_id', v_id, 'secret', v_secret);
end;
$$;
revoke all on function public.register_device(text, text) from public, anon;
grant execute on function public.register_device(text, text) to authenticated;

-- Empieza una sesion. Si ya hay una activa, la devuelve en lugar de crear otra.
create or replace function public.start_focus_session(
  p_minutes int, p_single_window boolean, p_device uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if p_minutes < 1 or p_minutes > 600 then raise exception 'invalid duration'; end if;
  if (public.active_session_for(v_user)).id is null then
    insert into public.focus_sessions (user_id, started_from_device, ends_at, single_window)
    values (
      v_user,
      (select d.id from public.devices d where d.id = p_device and d.user_id = v_user),
      now() + make_interval(mins => p_minutes),
      coalesce(p_single_window, false)
    );
  end if;
  return public.session_state(v_user);
end;
$$;
revoke all on function public.start_focus_session(int, boolean, uuid) from public, anon;
grant execute on function public.start_focus_session(int, boolean, uuid) to authenticated;

-- Salida de emergencia: cierra la sesion activa en todos los dispositivos.
create or replace function public.emergency_exit(p_reason text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  update public.focus_sessions
     set status = 'emergency_exit', emergency_reason = left(p_reason, 200), ended_at = now()
   where user_id = v_user and status = 'active' and ends_at > now();
  return public.session_state(v_user);
end;
$$;
revoke all on function public.emergency_exit(text) from public, anon;
grant execute on function public.emergency_exit(text) to authenticated;

create or replace function public.get_session_state()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return public.session_state(auth.uid());
end;
$$;
revoke all on function public.get_session_state() from public, anon;
grant execute on function public.get_session_state() to authenticated;

-- ---------------------------------------------------------------- RPC dispositivo

-- La usa el servicio nativo de Android (sin sesion de usuario). Solo responde
-- si el secreto del dispositivo es correcto.
create or replace function public.device_session_state(p_device uuid, p_secret text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_user uuid;
begin
  update public.devices d set last_seen_at = now()
   where d.id = p_device and d.secret_hash = encode(extensions.digest(p_secret, 'sha256'), 'hex')
  returning d.user_id into v_user;
  if v_user is null then raise exception 'invalid device'; end if;
  return public.session_state(v_user);
end;
$$;
revoke all on function public.device_session_state(uuid, text) from public;
grant execute on function public.device_session_state(uuid, text) to anon, authenticated;

-- Sesiones pasadas se marcan como completadas al consultarlas (no hace falta
-- un cron: el estado efectivo siempre se calcula con ends_at > now()).
create or replace view public.focus_history
with (security_invoker = true) as
select id, started_at, ends_at, single_window, emergency_reason, ended_at,
  case
    when status = 'emergency_exit' then 'emergency_exit'
    when ends_at <= now() then 'completed'
    else 'active'
  end as status,
  extract(epoch from (coalesce(ended_at, least(ends_at, now())) - started_at))::int / 60 as minutes
from public.focus_sessions;
