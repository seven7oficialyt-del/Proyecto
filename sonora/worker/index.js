// Cloudflare Worker: solo el administrador puede subir o borrar archivos en R2.
// Variables necesarias: SUPABASE_URL, SUPABASE_ANON_KEY, ADMIN_EMAIL
// Enlace (binding) de R2 necesario: BUCKET

const KEY_OK = /^(canciones|portadas)\/[A-Za-z0-9._-]+$/;

async function isAdmin(request, env) {
  const token = (request.headers.get("Authorization") || "").replace("Bearer ", "");
  if (!token) return false;
  const r = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: `Bearer ${token}`, apikey: env.SUPABASE_ANON_KEY },
  });
  if (!r.ok) return false;
  const user = await r.json();
  return (user.email || "").toLowerCase() === env.ADMIN_EMAIL.toLowerCase();
}

export default {
  async fetch(request, env) {
    if (request.method !== "PUT" && request.method !== "DELETE") {
      return new Response("Método no permitido", { status: 405 });
    }
    if (!(await isAdmin(request, env))) {
      return new Response("No autorizado", { status: 401 });
    }
    const key = decodeURIComponent(new URL(request.url).pathname.slice(1));
    if (!KEY_OK.test(key)) {
      return new Response("Ruta no válida", { status: 400 });
    }
    if (request.method === "DELETE") {
      await env.BUCKET.delete(key);
      return new Response('{"ok":true}', { status: 200 });
    }
    await env.BUCKET.put(key, request.body, {
      httpMetadata: {
        contentType: request.headers.get("Content-Type") || "application/octet-stream",
      },
    });
    return new Response('{"ok":true}', {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
};
