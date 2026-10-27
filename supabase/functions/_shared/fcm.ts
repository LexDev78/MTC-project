// FCM HTTP v1 sender — OAuth2 via a Google service account, no SDK.
//
// Kept separate from `send-push-notification/index.ts` so it stays reusable
// untouched when iOS is added: the v1 API and this OAuth flow are identical
// across platforms, only the `android`/`apns` sub-block of the message
// payload differs (see `buildMessage` below).
//
// Deliberately dependency-free: the JWT is signed with Deno's built-in
// `crypto.subtle` rather than a JWT library, so there's no third-party code
// (and no pinned version to rot) between a service-account private key and
// the wire.

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/// Reads the service account from `FCM_SERVICE_ACCOUNT_JSON_B64`.
///
/// Base64 rather than raw JSON on purpose: the PEM private key inside is
/// multi-line, and multi-line values are exactly what gets mangled when an
/// env var passes through a shell, a `.env` parser, or the Supabase
/// dashboard's secret field. Base64 makes it a single opaque token.
function loadServiceAccount(): ServiceAccount {
  const encoded = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON_B64");
  if (!encoded) {
    throw new Error(
      "FCM_SERVICE_ACCOUNT_JSON_B64 is not set — see supabase/functions/.env.example",
    );
  }
  const json = new TextDecoder().decode(
    Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0)),
  );
  const parsed = JSON.parse(json) as Partial<ServiceAccount>;
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error(
      "FCM_SERVICE_ACCOUNT_JSON_B64 decoded, but is missing client_email/private_key/project_id",
    );
  }
  return parsed as ServiceAccount;
}

function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/// Turns the PEM `private_key` into a key `crypto.subtle` can sign with.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // The JSON carries the PEM with literal "\n" escapes; `JSON.parse` already
  // turned those into real newlines, so only the armour lines are stripped.
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

// Access tokens last an hour; the local runtime's `policy = "per_worker"`
// (supabase/config.toml) and the hosted runtime both reuse a warm isolate
// across invocations, so caching here avoids re-signing a JWT and doing an
// extra network round-trip on every single push.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // 60s of slack so a token that's about to lapse mid-request isn't reused.
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const unsigned = `${base64UrlEncode(encoder.encode(JSON.stringify(header)))}.${
    base64UrlEncode(encoder.encode(JSON.stringify(claims)))
  }`;
  const key = await importPrivateKey(account.private_key);
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned)),
  );
  const assertion = `${unsigned}.${base64UrlEncode(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(
      `OAuth2 token exchange failed (${response.status}): ${await response.text()}`,
    );
  }
  const body = await response.json() as { access_token: string; expires_in: number };
  cachedToken = { value: body.access_token, expiresAt: now + body.expires_in };
  return body.access_token;
}

export interface PushPayload {
  token: string;
  title: string;
  body: string;
  /// Mirrored into the notification's `data`, which is what the client's tap
  /// handler reads (`lib/core/push/notification_tap_router.dart`) to decide
  /// where to navigate.
  type: string;
  referenceId: string | null;
  notificationId: string;
}

export type SendOutcome =
  | { ok: true }
  /// The token is dead (app uninstalled, token rotated) — the caller prunes
  /// it so future sends stop wasting a call on it.
  | { ok: false; stale: true; detail: string }
  | { ok: false; stale: false; detail: string };

function buildMessage(payload: PushPayload) {
  return {
    message: {
      token: payload.token,
      notification: { title: payload.title, body: payload.body },
      // Every `data` value must be a string — FCM rejects other JSON types.
      // A missing reference becomes "", which the client treats exactly like
      // null (see `notification_tap_router.dart`).
      data: {
        type: payload.type,
        referenceId: payload.referenceId ?? "",
        notificationId: payload.notificationId,
      },
      android: {
        priority: "HIGH",
        notification: { sound: "default" },
      },
      // iOS (`apns: { ... }`) goes here when that platform is wired up —
      // nothing else in this file changes.
    },
  };
}

/// FCM reports a permanently-dead token with one of these; anything else
/// (5xx, quota, transient network) is worth keeping the token for.
function isStaleTokenError(status: number, body: string): boolean {
  if (status === 404) return true;
  if (status !== 400 && status !== 403) return false;
  return body.includes("UNREGISTERED") || body.includes("INVALID_ARGUMENT");
}

export async function sendPush(payload: PushPayload): Promise<SendOutcome> {
  const account = loadServiceAccount();
  const accessToken = await getAccessToken(account);

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildMessage(payload)),
    },
  );

  if (response.ok) return { ok: true };

  const detail = await response.text();
  return {
    ok: false,
    stale: isStaleTokenError(response.status, detail),
    detail: `FCM ${response.status}: ${detail}`,
  };
}
