import { authorizedDispatch } from "../_shared/hospital_dispatch_auth.mjs";
import { createClient } from "@supabase/supabase-js";
import { deliveryConfig, sendHospitalDelivery } from "../_shared/hospital_delivery.mjs";

const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
});

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  const secret = Deno.env.get("HOSPITAL_DISPATCH_SECRET");
  if (!authorizedDispatch(request.headers.get("Authorization"), secret)) {
    return reply({ error: "authentication_required" }, 401);
  }
  const config = deliveryConfig();
  if (!config) return reply({ error: "providers_not_configured" }, 503);
  const server = createClient(
    Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const { data: batch, error: claimError } = await server.rpc("hospital_delivery_claim", {
    p_limit: 20, p_channels: config.channels,
  });
  if (claimError || !Array.isArray(batch)) return reply({ error: "queue_unavailable" }, 503);
  let sent = 0;
  let failed = 0;
  for (const item of batch) {
    let reference: string | null = null;
    let errorCode: string | null = null;
    try {
      reference = await sendHospitalDelivery(item, config);
    } catch (error) {
      errorCode = error instanceof Error &&
          ["invalid_delivery", "provider_not_configured", "provider_http_error", "provider_response_invalid"].includes(error.message)
        ? error.message : "provider_network_error";
    }
    const { error: finishError } = await server.rpc("hospital_delivery_finish", {
      p_id: item.id,
      p_sent: reference !== null,
      p_provider_ref: reference,
      p_error_code: errorCode,
    });
    if (finishError) return reply({ error: "queue_update_failed", sent, failed }, 503);
    if (reference !== null) sent++; else failed++;
  }
  return reply({ claimed: batch.length, sent, failed });
});
