// ذبائح البحرين: Bahrain address -> map point, through Google Maps when GOOGLE_MAPS_KEY is set.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown) => new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json" } });
const clean = (v: unknown) => String(v ?? "").replace(/[^\p{L}\p{N} ]/gu, "").trim().slice(0, 40);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const key = Deno.env.get("GOOGLE_MAPS_KEY");
  if (!key) return json({ ok: false, reason: "no_key" });
  try {
    const b = await req.json();
    const building = clean(b.building), road = clean(b.road), block = clean(b.block), area = clean(b.area), city = clean(b.city);
    const tries = [
      [building && `Building ${building}`, road && `Road ${road}`, block && `Block ${block}`, area || city, "Bahrain"],
      [road && `Road ${road}`, block && `Block ${block}`, area || city, "Bahrain"],
      [block && `Block ${block}`, area || city, "Bahrain"],
    ].map((p) => p.filter(Boolean).join(", "));
    const list = [...new Set(tries)];
    for (let i = 0; i < list.length; i++) {
      const address = list[i];
      const u = new URL("https://maps.googleapis.com/maps/api/geocode/json");
      u.searchParams.set("address", address);
      u.searchParams.set("components", "country:BH");
      u.searchParams.set("language", "ar");
      u.searchParams.set("key", key);
      const r = await (await fetch(u)).json();
      const g = r?.results?.[0];
      if (r?.status === "OK" && g && (!g.partial_match || i === list.length - 1)) {
        return json({ ok: true, lat: g.geometry.location.lat, lng: g.geometry.location.lng, precision: g.geometry.location_type, matched: address });
      }
    }
    return json({ ok: false, reason: "not_found" });
  } catch (e) {
    return json({ ok: false, reason: (e as Error).message });
  }
});
