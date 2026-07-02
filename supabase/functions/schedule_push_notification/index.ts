import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const ONESIGNAL_API_KEY = Deno.env.get("ONESIGNAL_API_KEY") || "";
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "";

interface PushRequest {
  type: "daily_log_reminder" | "streak_milestone" | "challenge_complete" | "level_up" | "badge_earned" | "weekly_summary" | "leaderboard_overtaken";
  user_id: string;
  data?: Record<string, any>;
  scheduled_time?: string; // ISO 8601 for future sends
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload: PushRequest = await req.json();

    // In a production app, we would verify the user's notification preferences
    // For this implementation, we will query user preferences or default to enabled.
    const { data: prefs, error: prefsError } = await supabase
      .from("notification_preferences")
      .select("*")
      .eq("user_id", payload.user_id)
      .maybeSingle();

    // Check if notification type is enabled. Default to true if preferences table does not exist or user doesn't have it.
    if (prefs) {
      const prefKey = `${payload.type}`;
      if (prefKey in prefs && !prefs[prefKey]) {
        console.log(`User ${payload.user_id} has disabled notification type ${payload.type}`);
        return new Response(JSON.stringify({ skipped: true, reason: "disabled_by_user" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    const title = getTitleForType(payload.type);
    const message = getMessageForType(payload.type, payload.data);

    // If OneSignal credentials are not set, log and return mock success to prevent failure in local testing
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_API_KEY) {
      console.warn("OneSignal credentials not set. Simulating push notification delivery.");
      return new Response(
        JSON.stringify({
          success: true,
          mock: true,
          title,
          message,
          payload,
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const oneSignalPayload = {
      app_id: ONESIGNAL_APP_ID,
      include_external_user_ids: [payload.user_id],
      headings: { en: title },
      contents: { en: message },
      data: payload.data || {},
      ios_channel_id: "default",
      android_channel_id: "default",
      ttl: 86400, // 24 hours
      ...(payload.scheduled_time && {
        send_after: new Date(payload.scheduled_time).toISOString(),
      }),
    };

    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${ONESIGNAL_API_KEY}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify(oneSignalPayload),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error("OneSignal error:", result);
      return new Response(JSON.stringify({ error: result }), {
        status: response.status,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ success: true, notification_id: result.id, title, message }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

function getTitleForType(type: string): string {
  const titles: Record<string, string> = {
    daily_log_reminder: "🌿 How was your day?",
    streak_milestone: "🔥 Streak Milestone!",
    challenge_complete: "🎉 Challenge Complete!",
    level_up: "⬆️ Level Up!",
    badge_earned: "🏅 New Badge Unlocked!",
    weekly_summary: "📊 Weekly Summary",
    leaderboard_overtaken: "💪 Overtaken on Leaderboard!",
  };
  return titles[type] || "NeutraWise";
}

function getMessageForType(type: string, data?: Record<string, any>): string {
  switch (type) {
    case "daily_log_reminder":
      return "Log your activity and keep your streak alive!";
    case "streak_milestone":
      return `You've reached ${data?.streak_days || 7} days in a row! 🏆`;
    case "challenge_complete":
      return `Challenge "${data?.challenge_name || "Eco Challenge"}" complete! +${data?.xp || 100} XP`;
    case "level_up":
      return `You're now Level ${data?.new_level || 2} — ${data?.level_title || "Green Sprout"}! 🌟`;
    case "badge_earned":
      return `You earned the "${data?.badge_name || "Special Badge"}" badge! Check your profile.`;
    case "weekly_summary":
      return `Your week in review: ${data?.co2_saved || 0} kg CO₂ saved, ${data?.streak || 0} days active.`;
    case "leaderboard_overtaken":
      return `${data?.overtaker_name || "Someone"} just overtook you on the leaderboard!`;
    default:
      return "Check your progress!";
  }
}
