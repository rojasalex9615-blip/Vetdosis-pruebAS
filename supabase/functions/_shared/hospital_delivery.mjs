const message = "Tienes un aviso de hospitalización pendiente. Abre VetDosis Pro.";

export function deliveryConfig(get = (name) => Deno.env.get(name)) {
  const fcmProject = get("HOSPITAL_FCM_PROJECT_ID");
  const fcmEmail = get("HOSPITAL_FCM_CLIENT_EMAIL");
  const fcmKey = get("HOSPITAL_FCM_PRIVATE_KEY");
  const waToken = get("HOSPITAL_WHATSAPP_ACCESS_TOKEN");
  const waPhone = get("HOSPITAL_WHATSAPP_PHONE_NUMBER_ID");
  const waTemplate = get("HOSPITAL_WHATSAPP_TEMPLATE");
  const waVersion = get("HOSPITAL_WHATSAPP_GRAPH_VERSION");
  const channels = [];
  if (fcmProject && fcmEmail && fcmKey) channels.push("fcm");
  if (waToken && waPhone && waTemplate && /^v[0-9]+\.[0-9]+$/.test(waVersion ?? "")) {
    channels.push("whatsapp");
  }
  if (channels.length === 0) return null;
  return { fcmProject, fcmEmail, fcmKey, waToken, waPhone, waTemplate, waVersion, channels };
}

function base64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

export async function fcmAccessToken(config, fetcher = fetch) {
  const pem = config.fcmKey.replace(/\\n/g, "\n");
  const raw = atob(pem.replace(/-----[^-]+-----|\s/g, ""));
  const key = await crypto.subtle.importKey(
    "pkcs8", Uint8Array.from(raw, (char) => char.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64url(new TextEncoder().encode(JSON.stringify({
    iss: config.fcmEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 1800,
  })));
  const input = `${header}.${claims}`;
  const signature = base64url(new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input),
  )));
  const response = await fetcher("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${input}.${signature}`,
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error("provider_http_error");
  const result = await response.json();
  if (typeof result.access_token !== "string" || !result.access_token) {
    throw new Error("provider_response_invalid");
  }
  return result.access_token;
}

export async function sendHospitalDelivery(item, config, getToken = fcmAccessToken, fetcher = fetch) {
  if (!item || typeof item.destination !== "string") throw new Error("invalid_delivery");
  let endpoint, token, payload;
  if (item.channel === "fcm") {
    if (!config.channels?.includes("fcm")) throw new Error("provider_not_configured");
    if (!/^[A-Za-z0-9:._~-]{20,4096}$/.test(item.destination)) throw new Error("invalid_delivery");
    token = await getToken(config, fetcher);
    endpoint = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(config.fcmProject)}/messages:send`;
    payload = { message: {
      token: item.destination,
      notification: { title: "VetDosis Pro", body: message },
      data: { kind: "hospital_notice" },
    } };
  } else if (item.channel === "whatsapp") {
    if (!config.channels?.includes("whatsapp")) throw new Error("provider_not_configured");
    if (!/^\+[1-9][0-9]{7,14}$/.test(item.destination)) throw new Error("invalid_delivery");
    token = config.waToken;
    endpoint = `https://graph.facebook.com/${config.waVersion}/${encodeURIComponent(config.waPhone)}/messages`;
    payload = {
      messaging_product: "whatsapp", to: item.destination.slice(1), type: "template",
      template: { name: config.waTemplate, language: { code: "es_MX" } },
    };
  } else throw new Error("invalid_delivery");
  const response = await fetcher(endpoint, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error("provider_http_error");
  const result = await response.json();
  const reference = item.channel === "fcm" ? result.name : result.messages?.[0]?.id;
  if (typeof reference !== "string" || !reference || reference.length > 200) {
    throw new Error("provider_response_invalid");
  }
  return reference;
}
