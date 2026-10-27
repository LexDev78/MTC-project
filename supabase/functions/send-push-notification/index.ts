// Fan-out of one `notifications` row to every device the recipient has
// registered. Triggered by a Database Webhook on `AFTER INSERT ON
// public.notifications`, so it hooks the single insert point every one of
// the app's nine notification types already goes through
// (`NotificationRepository.add`) — no per-feature wiring needed.
//
// The webhook is configured per environment (Studio → Database → Webhooks),
// not in a migration: its target URL and auth header differ between the
// local stack and the hosted project, so it isn't schema.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

/// The standard Supabase Database Webhook body.
interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: {
    id: string;
    user_id: string;
    type: string;
    title: string;
    body: string;
    reference_id: string | null;
  } | null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Shared-secret gate. Without it this endpoint would take any POST and
  // push attacker-chosen text to any `user_id` — the same notification
  // spoofing `0033_fix_notification_spoofing_payout_amount_and_upload_limits.sql`
  // already closed at the RLS level, reopened at the edge. The database
  // trigger sends this header (see `0041_push_webhook_never_blocks_insert.sql`,
  // which reads the matching value from Vault); nothing else legitimately
  // calls this function.
  //
  // A dedicated secret rather than the service-role key: that key opens the
  // whole database, so handing a copy to one narrow webhook is more
  // privilege than this needs — and its value isn't even stable, since a
  // project can be on either the legacy JWT keys or the newer
  // `sb_secret_...` format, which is exactly what made the first hosted
  // attempt fail.
  const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!expectedSecret) {
    return jsonResponse(
      { error: "PUSH_WEBHOOK_SECRET is not set — see supabase/functions/.env.example" },
      500,
    );
  }
  if (request.headers.get("Authorization") !== `Bearer ${expectedSecret}`) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let payload: WebhookPayload;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  // Only INSERTs carry a new notification to deliver; an UPDATE here is a
  // read-receipt flip (`is_read`), which must not re-push.
  if (payload.type !== "INSERT" || !payload.record) {
    return jsonResponse({ skipped: "not an insert" });
  }
  const record = payload.record;

  // Distinct from the webhook secret above: this one is the actual database
  // credential, needed to reach the `security definer` RPCs below. Both are
  // injected by the runtime (hosted) or the `.env` file (local).
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not set" },
      500,
    );
  }
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // `service_role` has no direct table grants in this schema (see
  // `0001_initial_schema.sql`, section 6) — reads go through a
  // `security definer` RPC, which is also what resolves the staff fan-out:
  // `notifications.user_id` may be the shared MTC storefront id rather than
  // one person's, in which case every staff member's device is returned.
  const { data: tokenRows, error: tokenError } = await supabase.rpc(
    "get_device_tokens_for_notification_user",
    { p_user_id: record.user_id },
  );
  if (tokenError) {
    return jsonResponse({ error: `Token lookup failed: ${tokenError.message}` }, 500);
  }

  const tokens = ((tokenRows ?? []) as { fcm_token: string }[])
    .map((row) => row.fcm_token)
    .filter((token): token is string => Boolean(token));

  if (tokens.length === 0) {
    return jsonResponse({ delivered: 0, skipped: "recipient has no device" });
  }

  let delivered = 0;
  const pruned: string[] = [];
  const failures: string[] = [];

  // Sequential rather than `Promise.all`: a recipient has a handful of
  // devices at most, and the shared OAuth token cache in `fcm.ts` warms on
  // the first call — firing them all at once would have every one of them
  // miss that cache and sign its own JWT.
  for (const token of tokens) {
    // `sendPush` throws rather than returns on a *configuration* problem (a
    // missing or malformed `FCM_SERVICE_ACCOUNT_JSON_B64`) and on anything
    // the fetch layer rejects outright. Caught per token so one bad token —
    // or a key that isn't set at all — degrades into a recorded failure
    // instead of a bare 500 that tells the logs nothing and hands the
    // webhook an error worth retrying, for a side channel that should never
    // look like the originating action failed.
    let outcome;
    try {
      outcome = await sendPush({
        token,
        title: record.title,
        body: record.body,
        type: record.type,
        referenceId: record.reference_id,
        notificationId: record.id,
      });
    } catch (error) {
      failures.push(error instanceof Error ? error.message : String(error));
      continue;
    }

    if (outcome.ok) {
      delivered++;
      continue;
    }
    if (outcome.stale) {
      const { error } = await supabase.rpc("prune_device_token", {
        p_fcm_token: token,
      });
      if (error) {
        failures.push(`prune failed: ${error.message}`);
      } else {
        pruned.push(token);
      }
      continue;
    }
    failures.push(outcome.detail);
  }

  // 200 even with partial failures: this is a fire-and-forget side channel
  // and the webhook has no retry semantics worth triggering — a missed push
  // must never look like the originating action failed. The counts are
  // returned so the function's logs stay diagnosable.
  return jsonResponse({
    delivered,
    pruned: pruned.length,
    failed: failures.length,
    failures,
  });
});
