// ذبائح: backups of every public table into the private «backups» bucket (gzip JSON).
// Callers: a super admin (Authorization) with actions create | link | remove,
// or the daily pg_cron job (x-hook) with action auto.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-hook",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const BUCKET = "backups";

async function gzip(text: string): Promise<Uint8Array> {
  const cs = new CompressionStream("gzip");
  const stream = new Blob([text]).stream().pipeThrough(cs);
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function exportAll(tables: string[]) {
  const data: Record<string, unknown[]> = {};
  const counts: Record<string, number> = {};
  for (const t of tables) {
    const rows: unknown[] = [];
    for (let from = 0; ; from += 1000) {
      const { data: page, error } = await admin.from(t).select("*").range(from, from + 999);
      if (error) throw new Error(`${t}: ${error.message}`);
      rows.push(...(page ?? []));
      if (!page || page.length < 1000) break;
    }
    data[t] = rows;
    counts[t] = rows.length;
  }
  return { data, counts };
}

async function create(kind: "manual" | "auto", by: string | null) {
  const { data: cfg, error } = await admin.rpc("backup_server_config");
  if (error) throw new Error(error.message);
  const tables: string[] = cfg.tables ?? [];
  const { data, counts } = await exportAll(tables);
  const now = new Date();
  const stamp = now.toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const file = `${stamp}-${kind}.json.gz`;
  const body = await gzip(JSON.stringify({ app: "dhabaeh", version: 1, created_at: now.toISOString(), kind, tables: data }));
  const up = await admin.storage.from(BUCKET).upload(file, body, { contentType: "application/gzip", upsert: false });
  if (up.error) throw new Error(up.error.message);
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  const { data: row } = await admin.from("backup_log").insert({
    file, kind, size_bytes: body.byteLength, tables: tables.length, total_rows: total, summary: counts, created_by: by,
  }).select().single();
  if (kind === "auto") await prune();
  return row;
}

// Keep only the newest N automatic backups (manual ones stay until deleted).
async function prune() {
  const { data: s } = await admin.from("platform_settings").select("backup_keep").eq("id", 1).maybeSingle();
  const keep = Math.max(1, Number(s?.backup_keep ?? 14));
  const { data: autos } = await admin.from("backup_log").select("id, file").eq("kind", "auto")
    .order("created_at", { ascending: false });
  for (const b of (autos ?? []).slice(keep)) await removeOne(b.id, b.file);
}

async function removeOne(id: string, file: string) {
  await admin.storage.from(BUCKET).remove([file]);
  await admin.from("backup_log").delete().eq("id", id);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const b = await req.json().catch(() => ({}));
    const hook = req.headers.get("x-hook");
    if (hook) {
      const { data: cfg } = await admin.rpc("backup_server_config");
      if (!cfg?.hook || hook !== cfg.hook) return json({ error: "forbidden" }, 403);
      if (b.action !== "auto") return json({ error: "unknown action" }, 400);
      return json({ ok: true, backup: await create("auto", null) });
    }

    // Super admins only.
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
    const { data: u } = await admin.auth.getUser(token);
    if (!u?.user) return json({ error: "سجّل دخولك أولاً" }, 401);
    const { data: acc } = await admin.from("admin_access").select("is_super").eq("user_id", u.user.id).maybeSingle();
    if (!acc?.is_super) return json({ error: "للمدير العام فقط" }, 403);

    if (b.action === "create") return json({ ok: true, backup: await create("manual", u.user.id) });

    const { data: row } = await admin.from("backup_log").select("id, file").eq("id", b.id ?? "").maybeSingle();
    if (!row) return json({ error: "النسخة غير موجودة" }, 404);
    if (b.action === "link") {
      const { data, error } = await admin.storage.from(BUCKET).createSignedUrl(row.file, 600, { download: `dhabaeh-${row.file}` });
      if (error) throw new Error(error.message);
      return json({ ok: true, url: data.signedUrl });
    }
    if (b.action === "remove") {
      await removeOne(row.id, row.file);
      return json({ ok: true });
    }
    return json({ error: "unknown action" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }
});
