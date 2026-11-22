import { betaAccess } from "../_shared/beta_access.ts";
import { createClient } from "@supabase/supabase-js";
import { providerRequest, providerText } from "../_shared/ai_providers.mjs";
import {
  helpMessages,
  limitedHelpRequest,
  starterRuntime,
} from "../_shared/starter_help.mjs";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-client-info,x-vetdosis-build",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
async function helpChatHistory(user, chat) {
  const { data, error } = await user.rpc("ai_messages_read", { p_chat: chat });
  if (error) throw new Error("help_history_denied");
  const rows = (data ?? []).filter((m) =>
    m && (m.role === "user" || m.role === "assistant") &&
    typeof m.body === "string" && m.body.length > 0
  ).slice(-12).map((m) => ({ role: m.role, content: m.body }));
  if (!rows.length) throw new Error("help_history_empty");
  return rows;
}
Deno.serve(async (req) => {
  const reply = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: {
        ...cors,
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
  if (req.method === "OPTIONS") return reply({});
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  const token = req.headers.get("Authorization");
  if (!token?.startsWith("Bearer ")) {
    return reply({ error: "authentication_required" }, 401);
  }
  const user = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: token, "x-vetdosis-build": req.headers.get("x-vetdosis-build") ?? "" } },
      auth: { persistSession: false },
    },
  );
  const { data: identity, error: authError } = await user.auth.getUser();
  if (authError || !identity.user) {
    return reply({ error: "authentication_required" }, 401);
  }
  if (!await betaAccess(user, true)) return reply({ error: "beta_write_denied" }, 403);
  const server = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const actor = identity.user.id;
  let claimed: string | null = null;
  try {
    const body = await req.text();
    if (body.length > 2000) return reply({ error: "request_too_large" }, 413);
    const input = JSON.parse(body);
    if (!await betaAccess(user, true, input.clinic ?? null)) return reply({error:"beta_write_denied"},403);
    const runtime = starterRuntime((name: string) => Deno.env.get(name));
    if (input.action === "status") {
      const { data, error } = await user.rpc("starter_ai_status", {
        p_clinic: input.clinic,
      });
      if (error) return reply({ error: "access_denied" }, 403);
      return reply({
        ...data,
        enabled: !!runtime && data.enabled &&
          data.provider === runtime.provider && data.model === runtime.model,
      });
    }
    const isChat = typeof input.message === "string";
    if (
      input.action !== "send" || input.consent !== true ||
      Object.keys(input).some((k) =>
        ![
          "action",
          "clinic",
          "topic",
          "operation",
          "consent",
          "message",
          "chat",
        ].includes(k)
      )
    ) return reply({ error: "fixed_help_topics_only" }, 400);
    if (
      (input.message !== undefined && typeof input.message !== "string") ||
      (isChat && (
        input.message.trim().length < 1 || input.message.length > 1000 ||
        (input.chat != null && typeof input.chat !== "string")
      ))
    ) return reply({ error: "invalid_help_message" }, 400);
    if (!runtime) return reply({ error: "starter_ai_not_configured" }, 503);
    const { data: r, error: prepareError } = isChat
      ? await user.rpc("starter_ai_prepare_chat", {
        p_clinic: input.clinic,
        p_chat: input.chat ?? null,
        p_message: input.message,
        p_operation: input.operation,
      })
      : await user.rpc("starter_ai_prepare", {
        p_clinic: input.clinic,
        p_topic: input.topic,
        p_operation: input.operation,
      });
    if (prepareError) {
      return reply({
        error: prepareError.message.includes("daily_limit")
          ? "starter_ai_daily_limit"
          : prepareError.message.includes("invalid_help_message")
          ? "invalid_help_message"
          : "help_request_denied",
      }, 403);
    }
    if (r.state === "done") return reply({ chat: r.chat, state: r.state });
    if (r.state !== "queued") {
      return reply({ error: "request_started_or_failed" }, 409);
    }
    const { data: snapshot, error: claimError } = await server.rpc(
      "starter_ai_claim_server",
      { p_id: r.id, p_user: actor },
    );
    if (claimError) {
      return reply({ error: "request_already_claimed_or_denied" }, 409);
    }
    claimed = r.id;
    if (
      snapshot.provider !== runtime.provider || snapshot.model !== runtime.model
    ) throw new Error("configuration_mismatch");
    const messages = isChat
      ? helpMessages({ history: await helpChatHistory(user, r.chat) })
      : helpMessages(snapshot.topic);
    const request = limitedHelpRequest(
      providerRequest(
        runtime.provider,
        runtime.key,
        runtime.model,
        messages,
      ),
      runtime.provider,
    );
    const headers = new Headers();
    for (const [k, v] of Object.entries(request.headers)) {
      if (typeof v !== "string") throw new Error("invalid_header");
      headers.set(k, v);
    }
    const response = await fetch(request.url, {
      method: "POST",
      headers,
      body: JSON.stringify(request.body),
      redirect: "error",
      signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) throw new Error("provider_failed");
    const answer = providerText(runtime.provider, await response.json());
    if (!await betaAccess(user, true, input.clinic)) {
      await server.rpc("starter_ai_finish_server", {
        p_id: r.id,
        p_user: actor,
        p_body: "",
        p_success: false,
      });
      claimed = null;
      return reply({ error: "beta_write_denied" }, 403);
    }
    const { error: finishError } = await server.rpc(
      "starter_ai_finish_server",
      { p_id: r.id, p_user: actor, p_body: answer, p_success: true },
    );
    if (finishError) throw new Error("finish_failed");
    claimed = null;
    const { data: state, error: stateError } = isChat
      ? await user.rpc("starter_ai_prepare_chat", {
        p_clinic: input.clinic,
        p_chat: r.chat,
        p_message: input.message,
        p_operation: input.operation,
      })
      : await user.rpc("starter_ai_prepare", {
        p_clinic: input.clinic,
        p_topic: input.topic,
        p_operation: input.operation,
      });
    if (stateError || state.state !== "done") {
      return reply({ error: "access_changed" }, 409);
    }
    return reply({ chat: r.chat, state: "done" });
  } catch {
    if (claimed) {
      await server.rpc("starter_ai_finish_server", {
        p_id: claimed,
        p_user: actor,
        p_body: "",
        p_success: false,
      });
    }
    return reply({ error: "starter_ai_unavailable" }, 503);
  }
});
