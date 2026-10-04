// Sends one push notification through OneSignal.
//
// Called only by the database (public.send_push, via pg_net). The call is
// authenticated with a shared secret kept in Supabase Vault: the secret arrives in
// the `x-push-secret` header and is checked with the service-role-only RPC
// `verify_push_secret`. Deploy WITHOUT JWT verification because the caller is the
// database, not a signed-in user:
//   supabase functions deploy schedule_push_notification --no-verify-jwt
//
// Required function secrets (Dashboard > Edge Functions > Secrets):
//   ONESIGNAL_APP_ID, ONESIGNAL_API_KEY
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.
// Without the OneSignal secrets the function runs in "mock" mode (nothing is sent).
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const ONESIGNAL_API_KEY = Deno.env.get("ONESIGNAL_API_KEY") ?? "";
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") ?? "";

const TYPES = [
  "daily_log_reminder",
  "final_log_warning",
  "streak_expiration",
  "streak_milestone",
  "challenge_reminder",
  "challenge_complete",
  "level_up",
  "badge_earned",
  "weekly_summary",
  "leaderboard_overtaken",
  "quiz_available",
] as const;
type PushType = (typeof TYPES)[number];

interface PushRequest {
  type: PushType;
  user_id: string;
  data?: Record<string, unknown>;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Authenticate the caller (the database).
  const secret = req.headers.get("x-push-secret") ?? "";
  const { data: valid, error: verifyError } = await supabase.rpc(
    "verify_push_secret",
    { p_secret: secret },
  );
  if (verifyError || valid !== true) return json({ error: "Unauthorized" }, 401);

  try {
    // 2. Validate the request.
    const payload = (await req.json()) as PushRequest;
    if (!TYPES.includes(payload.type)) return json({ error: "Unknown type" }, 400);
    if (!UUID_RE.test(payload.user_id ?? "")) return json({ error: "Invalid user_id" }, 400);

    // 3. Respect the user's preferences (a missing column or row means "on").
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("*")
      .eq("user_id", payload.user_id)
      .maybeSingle();
    if (prefs && payload.type in prefs && prefs[payload.type] === false) {
      return json({ skipped: true, reason: "disabled_by_user" });
    }

    const title = getTitleForType(payload.type);
    const message = getMessageForType(payload.type, payload.data);

    // 4. Mock mode when OneSignal is not configured.
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_API_KEY) {
      console.warn("OneSignal credentials not set; skipping real delivery.");
      return json({ success: true, mock: true, title, message });
    }

    // 5. Deliver. The app calls OneSignal.login(userId), so target the external id.
    const authScheme = ONESIGNAL_API_KEY.startsWith("os_v2_") ? "Key" : "Basic";
    const response = await fetch("https://api.onesignal.com/notifications?c=push", {
      method: "POST",
      headers: {
        Authorization: `${authScheme} ${ONESIGNAL_API_KEY}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        target_channel: "push",
        include_aliases: { external_id: [payload.user_id] },
        headings: { en: title },
        contents: { en: message },
        data: { type: payload.type, ...(payload.data ?? {}) },
        ttl: 86400,
      }),
    });

    const result = await response.json();
    if (!response.ok) {
      console.error("OneSignal error:", result);
      return json({ error: result }, response.status);
    }
    return json({ success: true, notification_id: result.id, title, message });
  } catch (error) {
    console.error("Function error:", error);
    return json({ error: (error as Error)?.message ?? "Internal server error" }, 500);
  }
});

function getTitleForType(type: string): string {
  const titles: Record<string, string> = {
    daily_log_reminder: "🌿 How was your day?",
    final_log_warning: "⚠️ Last chance to log today!",
    streak_expiration: "🔥 Streak Expiring Soon!",
    streak_milestone: "🔥 Streak Milestone!",
    challenge_reminder: "📋 Challenge Reminder",
    challenge_complete: "🎉 Challenge Complete!",
    level_up: "⬆️ Level Up!",
    badge_earned: "🏅 New Badge Unlocked!",
    weekly_summary: "📊 Weekly Summary",
    leaderboard_overtaken: "💪 Overtaken on Leaderboard!",
    quiz_available: "🧠 New Quiz Available!",
  };
  return titles[type] ?? "NeutraWise";
}

function getMessageForType(type: string, data: Record<string, unknown> = {}): string {
  switch (type) {
    case "daily_log_reminder":
      return "Log your activity and keep your streak alive!";
    case "final_log_warning":
      return `Don't break your ${data.streak ?? 1}-day streak 🔥 Log anything to keep it alive.`;
    case "streak_expiration":
      return `Your ${data.streak ?? 1}-day streak resets at midnight. Log anything to save it!`;
    case "streak_milestone":
      return `${data.streak_days ?? 7} days in a row! You're a true eco-warrior. +${data.xp ?? 75} XP awarded!`;
    case "challenge_reminder":
      return `Day ${data.day ?? 1} of your "${data.challenge_name ?? "Eco Challenge"}" challenge. You've got this!`;
    case "challenge_complete":
      return `Challenge "${data.challenge_name ?? "Eco Challenge"}" complete! +${data.xp ?? 100} XP earned!`;
    case "level_up":
      return `You're now Level ${data.new_level ?? 2} — ${data.level_title ?? "Green Sprout"}! 🌍`;
    case "badge_earned":
      return `You earned the "${data.badge_name ?? "Special"}" badge! Check your profile.`;
    case "weekly_summary":
      return `Your week in review: ${data.co2_saved ?? 0} kg CO₂ saved, ${data.streak ?? 0}-day streak. Keep it up!`;
    case "leaderboard_overtaken":
      return `${data.overtaker_name ?? "Someone"} just overtook you${data.rank ? ` — you're now #${data.rank}` : ""}. Log today's activity to climb back up!`;
    case "quiz_available":
      return `Test your eco knowledge and earn up to ${data.xp ?? 130} XP — optional but fun!`;
    default:
      return "Check your progress!";
  }
}
