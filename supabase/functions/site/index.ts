// ذبائح: the app's web address. Super admins read the GitHub Pages status, check a domain's DNS,
// and attach / detach a custom domain. Changing GitHub needs the GH_TOKEN secret (fine-grained,
// repo nabeel421est/Dhabaeh: Pages, Variables and Actions read & write).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const GH = Deno.env.get("GH_TOKEN") ?? "";
const REPO = "nabeel421est/Dhabaeh";
const OWNER_HOST = "nabeel421est.github.io";
const PAGES_IPS = ["185.199.108.153", "185.199.109.153", "185.199.110.153", "185.199.111.153"];
const DOMAIN_RE = /^(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/;

async function gh(path: string, init: RequestInit = {}) {
  const r = await fetch(`https://api.github.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${GH}`, Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "dhabaeh-admin", "Content-Type": "application/json",
    },
  });
  const text = await r.text();
  const body = text ? JSON.parse(text) : {};
  return { ok: r.ok, status: r.status, body };
}

async function dns(name: string, type: string): Promise<string[]> {
  const r = await fetch(`https://dns.google/resolve?name=${encodeURIComponent(name)}&type=${type}`);
  const j = await r.json().catch(() => ({}));
  return (j.Answer ?? []).map((a: { data: string }) => String(a.data).replace(/\.$/, ""));
}

// Where the domain points now, and whether that matches GitHub Pages.
async function check(domain: string) {
  const apex = domain.split(".").length === 2;
  const a = await dns(domain, "A");
  const cname = await dns(domain, "CNAME");
  const ok = apex ? PAGES_IPS.every((ip) => a.includes(ip)) || (a.length > 0 && a.every((ip) => PAGES_IPS.includes(ip)))
    : cname.some((c) => c.toLowerCase() === OWNER_HOST) || (a.length > 0 && a.every((ip) => PAGES_IPS.includes(ip)));
  const wwwCname = apex ? await dns(`www.${domain}`, "CNAME") : [];
  return {
    domain, apex, a, cname, ok,
    www_ok: apex ? wwwCname.some((c) => c.toLowerCase() === OWNER_HOST) : null,
    expected: apex
      ? [...PAGES_IPS.map((ip) => ({ type: "A", host: "@", value: ip })), { type: "CNAME", host: "www", value: OWNER_HOST }]
      : [{ type: "CNAME", host: domain.split(".")[0], value: OWNER_HOST }],
  };
}

async function setVariable(value: string | null) {
  if (value === null) return gh(`/repos/${REPO}/actions/variables/PAGES_DOMAIN`, { method: "DELETE" });
  const up = await gh(`/repos/${REPO}/actions/variables/PAGES_DOMAIN`, {
    method: "PATCH", body: JSON.stringify({ name: "PAGES_DOMAIN", value }),
  });
  if (up.status === 404) {
    return gh(`/repos/${REPO}/actions/variables`, { method: "POST", body: JSON.stringify({ name: "PAGES_DOMAIN", value }) });
  }
  return up;
}

const redeploy = () =>
  gh(`/repos/${REPO}/actions/workflows/deploy.yml/dispatches`, { method: "POST", body: JSON.stringify({ ref: "main" }) });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
    const { data: u } = await admin.auth.getUser(token);
    if (!u?.user) return json({ error: "سجّل دخولك أولاً" }, 401);
    const { data: acc } = await admin.from("admin_access").select("is_super").eq("user_id", u.user.id).maybeSingle();
    if (!acc?.is_super) return json({ error: "للمدير العام فقط" }, 403);

    const b = await req.json().catch(() => ({}));
    const { data: s } = await admin.from("platform_settings").select("custom_domain").eq("id", 1).maybeSingle();
    const saved: string | null = s?.custom_domain ?? null;

    if (b.action === "status") {
      let pages: Record<string, unknown> | null = null;
      let health: Record<string, unknown> | null = null;
      let run: Record<string, unknown> | null = null;
      if (GH) {
        const p = await gh(`/repos/${REPO}/pages`);
        if (p.ok) pages = p.body;
        if (p.ok && p.body?.cname) {
          const h = await gh(`/repos/${REPO}/pages/health`);
          if (h.ok) health = h.body?.domain ?? null;
        }
        const r = await gh(`/repos/${REPO}/actions/workflows/deploy.yml/runs?per_page=1`);
        const last = r.body?.workflow_runs?.[0];
        if (last) run = { status: last.status, conclusion: last.conclusion, at: last.updated_at, url: last.html_url };
      }
      return json({
        github: GH.length > 0,
        default_url: `https://${OWNER_HOST}/Dhabaeh/`,
        url: pages?.html_url ?? (saved ? `https://${saved}/` : `https://${OWNER_HOST}/Dhabaeh/`),
        cname: pages?.cname ?? saved,
        https_enforced: pages?.https_enforced ?? null,
        https_certificate: (pages?.https_certificate as Record<string, unknown> | undefined)?.state ?? null,
        pages_status: pages?.status ?? null,
        health, run,
        dns: saved ? await check(saved) : null,
      });
    }

    if (b.action === "check") {
      const d = String(b.domain ?? "").trim().toLowerCase().replace(/^https?:\/\//, "").replace(/\/.*$/, "");
      if (!DOMAIN_RE.test(d)) return json({ error: "اكتب الدومين بشكل صحيح، مثل dhabaeh.com" }, 400);
      return json(await check(d));
    }

    if (!GH) return json({ error: "اربط مفتاح GitHub أولاً (GH_TOKEN)" }, 400);

    if (b.action === "attach") {
      const d = String(b.domain ?? "").trim().toLowerCase().replace(/^https?:\/\//, "").replace(/\/.*$/, "");
      if (!DOMAIN_RE.test(d)) return json({ error: "اكتب الدومين بشكل صحيح، مثل dhabaeh.com" }, 400);
      const p = await gh(`/repos/${REPO}/pages`, { method: "PUT", body: JSON.stringify({ cname: d }) });
      if (!p.ok) return json({ error: `GitHub: ${p.body?.message ?? p.status}` }, 400);
      const v = await setVariable(d);
      if (!v.ok) return json({ error: `GitHub variable: ${v.body?.message ?? v.status}` }, 400);
      await admin.from("platform_settings").update({ custom_domain: d }).eq("id", 1);
      const r = await redeploy();
      return json({ ok: true, domain: d, redeploy: r.ok });
    }

    if (b.action === "https") {
      const p = await gh(`/repos/${REPO}/pages`, { method: "PUT", body: JSON.stringify({ https_enforced: b.on === true }) });
      if (!p.ok) return json({ error: `GitHub: ${p.body?.message ?? p.status}` }, 400);
      return json({ ok: true });
    }

    if (b.action === "detach") {
      const p = await gh(`/repos/${REPO}/pages`, { method: "PUT", body: JSON.stringify({ cname: null }) });
      if (!p.ok) return json({ error: `GitHub: ${p.body?.message ?? p.status}` }, 400);
      await setVariable(null);
      await admin.from("platform_settings").update({ custom_domain: null }).eq("id", 1);
      const r = await redeploy();
      return json({ ok: true, redeploy: r.ok });
    }

    if (b.action === "redeploy") {
      const r = await redeploy();
      return r.ok ? json({ ok: true }) : json({ error: `GitHub: ${r.body?.message ?? r.status}` }, 400);
    }
    return json({ error: "unknown action" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }
});
