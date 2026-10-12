-- Pega esto en Supabase > SQL Editor > Run
-- (cambia TU_CORREO por tu correo de administrador)

create table songs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  artist text not null,
  audio_url text not null,
  cover_url text,
  created_at timestamptz default now()
);

alter table songs enable row level security;

create policy "todos pueden escuchar" on songs
  for select using (true);

create policy "solo admin sube" on songs
  for insert to authenticated
  with check ((auth.jwt() ->> 'email') = 'TU_CORREO');

create policy "solo admin borra" on songs
  for delete to authenticated
  using ((auth.jwt() ->> 'email') = 'TU_CORREO');
