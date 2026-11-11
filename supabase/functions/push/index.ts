// Sends Web Push notifications to users' phones. Called only by the database
// (pg_net) with the shared x-hook secret. VAPID keys are created on first run
// and kept in the database (private.push_keys), never in the app.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Cfg = { public: string | null; private: string | null; hook: string };
let cfg: Cfg | null = null;

async function config(): Promise<Cfg> {
  if (cfg?.public) return cfg;
  const { data, error } = await sb.rpc("push_server_config");
  if (error) throw error;
  let c = data as Cfg;
  if (!c.public || !c.private) {
    const k = webpush.generateVAPIDKeys();
    await sb.rpc("push_store_keys", { p_public: k.publicKey, p_private: k.privateKey });
    const again = await sb.rpc("push_server_config");
    c = again.data as Cfg;
  }
  cfg = c;
  return c;
}

const ids = (rows: { user_id: string | null }[] | null) =>
  (rows ?? []).map((r) => r.user_id).filter((x): x is string => !!x);

async function recipients(p: Record<string, unknown>): Promise<string[]> {
  const out = new Set<string>();
  const add = (xs: string[]) => xs.forEach((x) => out.add(x));
  const byRole = async (role: string) =>
    add(ids((await sb.from("user_roles").select("user_id").eq("role", role)).data));

  if (Array.isArray(p.users)) add(p.users as string[]);
  if (p.admins) await byRole("admin");
  const m = (p.merchant_staff ?? (p.audience === "merchant" ? p.merchant_id : null)) as string | null;
  if (m) {
    add(ids((await sb.from("user_roles").select("user_id").eq("role", "merchant_owner").eq("merchant_id", m)).data));
    const staff = (await sb.from("merchant_staff").select("user_id, perms").eq("merchant_id", m)).data ?? [];
    add(staff.filter((s: any) => p.merchant_staff ? s.perms?.orders === true : true).map((s: any) => s.user_id));
  }
  if (p.drivers_online) {
    const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    const live = ids((await sb.from("driver_locations").select("user_id:driver_id").eq("online", true).gte("updated_at", since)).data);
    if (live.length) add(live); else await byRole("driver");
  }
  switch (p.audience) {
    case "user": if (p.user_id) add([p.user_id as string]); break;
    case "customers": await byRole("customer"); break;
    case "merchants": await byRole("merchant_owner"); await byRole("merchant_staff"); break;
    case "drivers": await byRole("driver"); break;
    case "all": add(ids((await sb.from("push_subscriptions").select("user_id").not("user_id", "is", null)).data)); break;
  }
  return [...out];
}

Deno.serve(async (req) => {
  try {
    const c = await config();
    if (req.headers.get("x-hook") !== c.hook) return new Response("forbidden", { status: 403 });
    const p = await req.json();
    const users = await recipients(p);
    if (!users.length) return Response.json({ sent: 0 });
    const { data: subs } = await sb.from("push_subscriptions").select("id, endpoint, p256dh, auth").in("user_id", users);
    webpush.setVapidDetails("mailto:support@dhabaeh.app", c.public!, c.private!);
    const payload = JSON.stringify({
      title: p.title ?? "ذبائح البحرين",
      body: p.body ?? "",
      tag: p.tag ?? undefined,
      loud: !!p.loud,
      url: p.url ?? "./",
    });
    let sent = 0;
    const stale: number[] = [];
    await Promise.all((subs ?? []).map(async (s: any) => {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
          { TTL: 3600, urgency: p.loud ? "high" : "normal" },
        );
        sent++;
      } catch (e: any) {
        if (e?.statusCode === 404 || e?.statusCode === 410) stale.push(s.id);
      }
    }));
    if (stale.length) await sb.from("push_subscriptions").delete().in("id", stale);
    return Response.json({ sent, stale: stale.length });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
