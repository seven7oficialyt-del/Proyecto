# Sonora 🎧

App de música en streaming para Android (Flutter + Cloudflare R2 + Supabase).

## 1. Supabase (base de datos y tu login)
1. Crea un proyecto en supabase.com.
2. SQL Editor → pega `worker/supabase.sql` (cambia `TU_CORREO` por el tuyo) → Run.
3. Authentication → Users → **Add user** con tu correo y una contraseña.
4. Authentication → Sign In / Providers → desactiva **Allow new users to sign up**.
5. Project Settings → API: copia **Project URL** y **anon public key**.

## 2. Cloudflare Worker (para que solo tú subas música)
1. Cloudflare → Workers & Pages → Create → **Hello World** → nómbralo `sonora-upload` → Deploy.
2. Edit code → pega `worker/index.js` → Deploy.
3. Settings → Bindings → Add → **R2 bucket** → nombre de variable `BUCKET` → elige tu bucket `musica`.
4. Settings → Variables and Secrets → agrega (tipo texto): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ADMIN_EMAIL`.
5. Copia la URL del Worker (`https://sonora-upload.xxx.workers.dev`).

## 3. Configura la app
Edita `lib/config.dart` con: URL y anon key de Supabase, URL pública de R2 (`https://pub-xxxx.r2.dev`), URL del Worker y tu correo de admin.

## 4. Crear el APK con GitHub
1. Sube a tu repositorio la carpeta `.github` y la carpeta `sonora` (tal cual).
2. Actions → "Sonora - APK" → Run workflow.
3. Releases → descarga `Sonora.apk` e instálalo. Las siguientes versiones se instalan encima, sin desinstalar.

## Uso
- Toca el icono 🛡 arriba a la derecha → inicia sesión → sube canciones.
- Los usuarios escuchan sin cuenta y pueden descargar con la flecha ⬇.
