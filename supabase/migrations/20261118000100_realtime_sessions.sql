-- El PC escucha los cambios de sesion por Realtime (RLS sigue aplicando:
-- cada usuario solo recibe sus propias filas).
alter publication supabase_realtime add table public.focus_sessions;
