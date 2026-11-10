// ذبائح البحرين: account creation (sign-up, admin-created users, merchants, merchant staff)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
class HttpError extends Error { constructor(public status: number, msg: string) { super(msg); } }

const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(URL_, SERVICE, { auth: { persistSession: false } });

// Bahrain mobile/landline: 8 digits, optional 973 prefix
function normPhone(raw: unknown): string {
  const d = String(raw ?? "").replace(/\D/g, "").replace(/^00973|^973/, "");
  if (!/^\d{8}$/.test(d)) throw new HttpError(400, "رقم الجوال يجب أن يكون 8 أرقام");
  return d;
}
export const emailFor = (phone: string) => `${phone}@phone.dhabaeh.app`;
function need(v: unknown, label: string): string {
  const s = String(v ?? "").trim();
  if (!s) throw new HttpError(400, `${label} مطلوب`);
  return s;
}

async function findOrCreateUser(phone: string, password: string | undefined, fullName: string) {
  const { data: prof } = await admin.from("profiles").select("id").eq("phone", phone).maybeSingle();
  if (prof) {
    if (fullName) await admin.from("profiles").update({ full_name: fullName }).eq("id", prof.id).eq("full_name", "");
    return { id: prof.id as string, existed: true };
  }
  if (!password || password.length < 6) throw new HttpError(400, "كلمة المرور 6 أحرف على الأقل");
  const { data, error } = await admin.auth.admin.createUser({
    email: emailFor(phone), password, email_confirm: true,
    user_metadata: { full_name: fullName, phone },
  });
  if (error) throw new HttpError(400, error.message.includes("already") ? "الرقم مسجّل مسبقاً" : error.message);
  return { id: data.user.id, existed: false };
}

async function addRole(userId: string, role: string, merchantId: string | null = null) {
  let q = admin.from("user_roles").select("id").eq("user_id", userId).eq("role", role);
  q = merchantId ? q.eq("merchant_id", merchantId) : q.is("merchant_id", null);
  const { data } = await q.maybeSingle();
  if (!data) {
    const { error } = await admin.from("user_roles").insert({ user_id: userId, role, merchant_id: merchantId });
    if (error) throw new HttpError(400, error.message);
  }
}

async function callerClient(req: Request): Promise<SupabaseClient> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) throw new HttpError(401, "يجب تسجيل الدخول");
  return createClient(URL_, ANON, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
}
async function callerId(req: Request): Promise<string> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/, "");
  const { data } = await admin.auth.getUser(token);
  if (!data.user) throw new HttpError(401, "يجب تسجيل الدخول");
  return data.user.id;
}
async function requireAdmin(req: Request) {
  const c = await callerClient(req);
  const { data } = await c.rpc("is_admin");
  if (data !== true) throw new HttpError(403, "للإدارة فقط");
  return c;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json();
    const action = body.action as string;

    // ---- public sign-up: every new account is a customer ----
    if (action === "signup") {
      const phone = normPhone(body.phone);
      const name = need(body.full_name, "الاسم");
      const { data: exists } = await admin.from("profiles").select("id").eq("phone", phone).maybeSingle();
      if (exists) throw new HttpError(409, "الرقم مسجّل مسبقاً، سجّل الدخول");
      if (name.split(/\s+/).filter(Boolean).length < 3) throw new HttpError(400, "اكتب الاسم الثلاثي");
      const a = body.address ?? {};
      const addr = {
        city: need(a.city, "المدينة"),
        area: need(a.area, "المنطقة"),
        house: need(a.building, "المبنى"),
        road: need(a.road, "الطريق"),
        block: need(a.block, "المجمع"),
        flat: String(a.flat ?? "").trim() || null,
        note: String(a.note ?? "").trim() || null,
        lat: Number.isFinite(Number(a.lat)) && a.lat !== null && a.lat !== undefined ? Number(a.lat) : null,
        lng: Number.isFinite(Number(a.lng)) && a.lng !== null && a.lng !== undefined ? Number(a.lng) : null,
      };
      const cpr = String(body.cpr ?? "").replace(/\D/g, "");
      if (cpr && cpr.length !== 9) throw new HttpError(400, "الرقم الشخصي 9 أرقام");
      const email = String(body.email ?? "").trim();
      if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new HttpError(400, "البريد الإلكتروني غير صحيح");
      const u = await findOrCreateUser(phone, body.password, name);
      await admin.from("profiles").update({ area: addr.area, cpr: cpr || null, email: email || null }).eq("id", u.id);
      const { error: ae } = await admin.from("customer_addresses").insert({ ...addr, user_id: u.id });
      if (ae) throw new HttpError(400, ae.message);
      return json({ ok: true, email: emailFor(phone) });
    }

    // ---- admin: add a user with roles (customer / driver / merchant owner / staff / admin) ----
    if (action === "admin_create_user") {
      await requireAdmin(req);
      const phone = normPhone(body.phone);
      const name = need(body.full_name, "الاسم");
      const u = await findOrCreateUser(phone, body.password, name);
      if (body.area) await admin.from("profiles").update({ area: String(body.area) }).eq("id", u.id);
      const roles: string[] = Array.isArray(body.roles) ? body.roles : [];
      for (const r of roles) {
        if (r === "merchant_owner" || r === "merchant_staff") {
          const mid = need(body.merchant_id, "المتجر");
          await addRole(u.id, r, mid);
          if (r === "merchant_staff") {
            await admin.from("merchant_staff").upsert({ merchant_id: mid, user_id: u.id, title: body.title ?? "موظف", perms: body.perms ?? { orders: true } });
          } else {
            await admin.from("merchant_details").update({ owner_id: u.id }).eq("merchant_id", mid);
          }
        } else if (["customer", "driver", "admin"].includes(r)) {
          await addRole(u.id, r);
        }
      }
      return json({ ok: true, user_id: u.id, existed: u.existed });
    }

    // ---- admin: edit a user's name/area and set their exact roles (adds and removes) ----
    if (action === "admin_update_user") {
      await requireAdmin(req);
      const me = await callerId(req);
      const uid = need(body.user_id, "المستخدم");
      const wanted: { role: string; merchant_id: string | null }[] = (Array.isArray(body.roles) ? body.roles : [])
        .filter((r: { role?: string }) => ["admin", "merchant_owner", "merchant_staff", "driver", "customer"].includes(String(r?.role)))
        .map((r: { role: string; merchant_id?: string }) => ({
          role: r.role,
          merchant_id: r.role === "merchant_owner" || r.role === "merchant_staff" ? need(r.merchant_id, "المتجر") : null,
        }));
      if (wanted.length === 0) wanted.push({ role: "customer", merchant_id: null });
      if (uid === me && !wanted.some((r) => r.role === "admin")) {
        throw new HttpError(400, "لا يمكنك إزالة صلاحية الإدارة عن حسابك");
      }
      const key = (r: { role: string; merchant_id: string | null }) => `${r.role}|${r.merchant_id ?? ""}`;
      const { data: current } = await admin.from("user_roles").select("id, role, merchant_id").eq("user_id", uid);
      const want = new Set(wanted.map(key));
      for (const r of current ?? []) {
        if (want.has(key(r))) continue;
        await admin.from("user_roles").delete().eq("id", r.id);
        if (r.role === "merchant_staff" && r.merchant_id) {
          await admin.from("merchant_staff").delete().eq("merchant_id", r.merchant_id).eq("user_id", uid);
        }
      }
      const have = new Set((current ?? []).map(key));
      for (const r of wanted) {
        if (have.has(key(r))) continue;
        await addRole(uid, r.role, r.merchant_id);
        if (r.role === "merchant_staff") {
          await admin.from("merchant_staff").upsert({ merchant_id: r.merchant_id, user_id: uid, title: "موظف", perms: { orders: true } });
        } else if (r.role === "merchant_owner") {
          await admin.from("merchant_details").update({ owner_id: uid }).eq("merchant_id", r.merchant_id);
        }
      }
      const patch: Record<string, unknown> = {};
      if (body.full_name !== undefined) patch.full_name = need(body.full_name, "الاسم");
      if (body.area !== undefined) patch.area = String(body.area ?? "").trim() || null;
      if (Object.keys(patch).length) await admin.from("profiles").update(patch).eq("id", uid);
      return json({ ok: true });
    }

    // ---- admin: delete a user. Accounts with orders or money records are archived instead, to keep the history ----
    if (action === "admin_delete_user") {
      await requireAdmin(req);
      const me = await callerId(req);
      const uid = need(body.user_id, "المستخدم");
      if (uid === me) throw new HttpError(400, "لا يمكنك حذف حسابك");
      const linked: [string, string][] = [
        ["orders", "customer_id"], ["orders", "driver_id"], ["merchant_details", "owner_id"], ["order_events", "by_user"],
        ["wallet_ledger", "created_by"], ["payout_requests", "requested_by"], ["payout_events", "created_by"],
        ["subscription_requests", "requested_by"], ["subscription_requests", "reviewed_by"], ["driver_ledger", "driver_id"],
        ["driver_settlements", "driver_id"], ["driver_settlements", "created_by"], ["notifications", "created_by"],
      ];
      let history = false;
      for (const [t, col] of linked) {
        const { count } = await admin.from(t).select("*", { count: "exact", head: true }).eq(col, uid);
        if ((count ?? 0) > 0) { history = true; break; }
      }
      if (!history) {
        const { error } = await admin.auth.admin.deleteUser(uid);
        if (error) throw new HttpError(400, error.message);
        return json({ ok: true, mode: "deleted" });
      }
      await admin.from("user_roles").delete().eq("user_id", uid);
      await admin.from("merchant_staff").delete().eq("user_id", uid);
      await admin.from("profiles").update({ is_active: false, deleted_at: new Date().toISOString() }).eq("id", uid);
      await admin.auth.admin.updateUserById(uid, { ban_duration: "876000h" });
      return json({ ok: true, mode: "archived" });
    }

    // ---- admin: add a merchant with its owner account ----
    if (action === "admin_create_merchant") {
      const caller = await requireAdmin(req);
      const m = body.merchant ?? {};
      const ownerPhone = normPhone(m.owner_phone);
      const storePhone = normPhone(m.store_phone);
      const required: [string, string][] = [
        ["name", "اسم المتجر"], ["owner_name", "اسم المالك"], ["owner_cpr", "الرقم الشخصي"], ["cr_number", "السجل التجاري"],
        ["health_license", "الترخيص الصحي"], ["shop_no", "رقم المحل"], ["building", "المبنى"], ["road", "الطريق"],
        ["block", "المجمع"], ["address_area", "المنطقة"], ["iban", "IBAN"], ["account_name", "اسم الحساب"], ["bank_name", "اسم البنك"],
        ["logo_url", "شعار المتجر"],
      ];
      for (const [k, l] of required) need(m[k], l);
      const owner = await findOrCreateUser(ownerPhone, body.owner_password, m.owner_name);
      const { data: settings } = await admin.from("platform_settings").select("trial_days").eq("id", 1).single();
      const { data: merchant, error } = await admin.from("merchants").insert({
        name: m.name.trim(), logo_url: m.logo_url, store_phone: storePhone, area: m.address_area, description: m.description ?? null,
        plan: "trial", plan_ends: new Date(Date.now() + (settings?.trial_days ?? 14) * 864e5).toISOString().slice(0, 10),
      }).select().single();
      if (error) throw new HttpError(400, error.message);
      const { error: e2 } = await admin.from("merchant_details").insert({
        merchant_id: merchant.id, owner_id: owner.id, owner_name: m.owner_name, owner_phone: ownerPhone, owner_cpr: m.owner_cpr,
        cr_number: m.cr_number, vat_number: m.vat_number || null, health_license: m.health_license,
        shop_no: m.shop_no, building: m.building, road: m.road, block: m.block, address_area: m.address_area, address_note: m.address_note || null,
        iban: m.iban, account_name: m.account_name, bank_name: m.bank_name,
        doc_id_path: m.doc_id_path || null, doc_cr_path: m.doc_cr_path || null, doc_tax_path: m.doc_tax_path || null, doc_health_path: m.doc_health_path || null,
      });
      if (e2) { await admin.from("merchants").delete().eq("id", merchant.id); throw new HttpError(400, e2.message); }
      await addRole(owner.id, "merchant_owner", merchant.id);
      if (m.plan && m.plan !== "trial") await caller.rpc("admin_set_plan", { p_merchant: merchant.id, p_plan: m.plan });
      else await admin.from("subscriptions").insert({ merchant_id: merchant.id, plan: "trial", ends: merchant.plan_ends, amount: 0 });
      return json({ ok: true, merchant_id: merchant.id, owner_existed: owner.existed });
    }

    // ---- merchant owner (or staff with the staff permission) adds a staff member ----
    if (action === "merchant_add_staff") {
      const c = await callerClient(req);
      const mid = need(body.merchant_id, "المتجر");
      const { data: can } = await c.rpc("staff_can", { m: mid, perm: "staff" });
      const { data: isAdmin } = await c.rpc("is_admin");
      if (can !== true && isAdmin !== true) throw new HttpError(403, "لا تملك صلاحية إضافة موظفين");
      const phone = normPhone(body.phone);
      const u = await findOrCreateUser(phone, body.password, need(body.full_name, "الاسم"));
      await addRole(u.id, "merchant_staff", mid);
      const { error } = await admin.from("merchant_staff").upsert({ merchant_id: mid, user_id: u.id, title: body.title ?? "موظف", perms: body.perms ?? { orders: true } });
      if (error) throw new HttpError(400, error.message);
      return json({ ok: true, user_id: u.id, existed: u.existed });
    }

    throw new HttpError(400, "إجراء غير معروف");
  } catch (e) {
    const status = e instanceof HttpError ? e.status : 500;
    return json({ ok: false, error: (e as Error).message }, status);
  }
});
