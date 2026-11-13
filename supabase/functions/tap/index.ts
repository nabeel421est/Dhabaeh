// ذبائح: online payment through Tap (Apple Pay, cards, Benefit) on Tap's hosted page.
// Actions: status | create {order_id, return_url} | verify {charge_id}. A POST with a Tap charge
// body (no action) is the webhook. The order is marked paid only from a charge fetched from Tap.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const KEY = Deno.env.get("TAP_SECRET_KEY") ?? "";
const admin = createClient(URL_, SERVICE, { auth: { persistSession: false } });
const TAP = "https://api.tap.company/v2";
const ALLOWED_RETURN = [/^https:\/\/nabeel421est\.github\.io\//, /^http:\/\/localhost(:\d+)?\//];

async function tap(path: string, init: RequestInit = {}) {
  const r = await fetch(TAP + path, {
    ...init,
    headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", accept: "application/json" },
  });
  const body = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(body?.errors?.[0]?.description ?? `Tap ${r.status}`);
  return body;
}

// Fetch the charge from Tap and record the payment on its order.
async function settle(chargeId: string) {
  if (!/^chg_[A-Za-z0-9]+$/.test(chargeId)) throw new Error("رقم عملية غير صالح");
  const c = await tap(`/charges/${chargeId}`);
  const orderId = c?.metadata?.order_id;
  const { data: o } = await admin.from("orders").select("id, code, total, payment_status").eq("id", orderId).maybeSingle();
  if (!o) throw new Error("الطلب غير موجود");
  const paid = c.status === "CAPTURED" && c.currency === "BHD" && Number(c.amount) + 0.0005 >= Number(o.total);
  // Approval code from the card network, and Tap's payment reference.
  const auth = c?.transaction?.authorization_id ?? c?.reference?.acquirer ?? null;
  const ref = c?.reference?.payment ?? c?.reference?.track ?? null;
  if (paid && o.payment_status !== "paid") {
    await admin.from("orders").update({
      payment_status: "paid", gateway_charge: c.id, paid_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      payment_auth: auth, payment_ref: ref,
    }).eq("id", o.id);
  } else if (paid) {
    await admin.from("orders").update({ payment_auth: auth, payment_ref: ref }).eq("id", o.id);
  } else if (!paid) {
    await admin.from("orders").update({ gateway_charge: c.id }).eq("id", o.id);
  }
  return {
    order_id: o.id, code: o.code, status: c.status, paid: paid || o.payment_status === "paid",
    reason: c?.response?.message ?? null, reason_code: c?.response?.code ?? null,
    gateway_reason: c?.gateway?.response?.message ?? null, method: c?.source?.payment_method ?? c?.source?.id ?? null, auth, ref,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const b = await req.json().catch(() => ({}));
    const action = b?.action;

    if (!action) { // webhook from Tap
      if (typeof b?.id === "string" && KEY) await settle(b.id);
      return json({ ok: true });
    }
    if (action === "status") {
      return json({ configured: KEY.length > 0, mode: KEY.startsWith("sk_live") ? "live" : KEY ? "test" : null });
    }
    if (!KEY) return json({ error: "بوابة الدفع غير مربوطة بعد" }, 400);

    if (action === "verify") return json(await settle(String(b.charge_id ?? "")));

    if (action === "create") {
      const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
      const { data: u } = await admin.auth.getUser(token);
      if (!u?.user) return json({ error: "سجّل دخولك أولاً" }, 401);
      const ret = String(b.return_url ?? "");
      if (!ALLOWED_RETURN.some((r) => r.test(ret))) return json({ error: "رابط الرجوع غير مسموح" }, 400);
      const { data: o } = await admin.from("orders")
        .select("id, code, total, customer_id, customer_name, customer_phone, payment_status, payment_method_code, status")
        .eq("id", b.order_id).maybeSingle();
      if (!o || o.customer_id !== u.user.id) return json({ error: "غير مسموح" }, 403);
      if (o.payment_status === "paid") return json({ error: "الطلب مدفوع مسبقاً" }, 400);
      if (o.status === "cancelled") return json({ error: "الطلب ملغي" }, 400);
      const { data: m } = await admin.from("payment_methods").select("gateway").eq("code", o.payment_method_code).maybeSingle();
      if (m?.gateway !== "tap") return json({ error: "وسيلة الدفع لا تدعم الدفع الإلكتروني" }, 400);
      const phone = String(o.customer_phone ?? "").replace(/\D/g, "").slice(-8);
      const c = await tap("/charges", {
        method: "POST",
        body: JSON.stringify({
          amount: Number(Number(o.total).toFixed(3)),
          currency: "BHD",
          customer_initiated: true,
          threeDSecure: true,
          save_card: false,
          description: `طلب ${o.code}`,
          metadata: { order_id: o.id },
          reference: { transaction: String(o.code), order: String(o.code) },
          receipt: { email: false, sms: false },
          customer: {
            first_name: o.customer_name || "Customer",
            ...(phone.length === 8 ? { phone: { country_code: "973", number: phone } } : {}),
          },
          source: { id: "src_all" },
          post: { url: `${URL_}/functions/v1/tap` },
          redirect: { url: ret },
        }),
      });
      await admin.from("orders").update({ gateway_charge: c.id }).eq("id", o.id);
      return json({ url: c?.transaction?.url, charge_id: c.id });
    }
    return json({ error: "unknown action" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }
});
