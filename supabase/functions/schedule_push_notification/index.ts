import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const ONESIGNAL_API_KEY = Deno.env.get("ONESIGNAL_API_KEY") || "";
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "";

interface PushRequest {
  type:
    | "daily_log_reminder"
    | "final_log_warning"
    | "streak_expiration"
    | "streak_milestone"
    | "challenge_reminder"
    | "challenge_complete"
    | "level_up"
    | "badge_earned"
    | "weekly_summary"
    | "leaderboard_overtaken"
    | "quiz_available";
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

    // Query user notification preferences
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("*")
      .eq("user_id", payload.user_id)
      .maybeSingle();

    // Check if notification type is enabled by user
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

    // If OneSignal credentials are not set in environment, simulate push notification delivery
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
      data: { type: payload.type, ...payload.data },
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
        Authorization: `Basic ${ONESIGNAL_API_KEY}`,
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
  } catch (error: any) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ error: error?.message || "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
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
  return titles[type] || "NeutraWise";
}

function getMessageForType(type: string, data?: Record<string, any>): string {
  switch (type) {
    case "daily_log_reminder":
      return "Log your activity and keep your streak alive!";
    case "final_log_warning":
      return `Don't break your ${data?.streak || 1}-day streak 🔥`;
    case "streak_expiration":
      return `Your ${data?.streak || 1}-day streak will reset at midnight if you don't log!`;
    case "streak_milestone":
      return `${data?.streak_days || 7} days in a row! You're a true eco-warrior. +${data?.xp || 50} XP awarded!`;
    case "challenge_reminder":
      return `Day ${data?.day || 1} of your "${data?.challenge_name || "Eco Challenge"}". You've got this!`;
    case "challenge_complete":
      return `Challenge "${data?.challenge_name || "Eco Challenge"}" complete! +${data?.xp || 100} XP earned!`;
    case "level_up":
      return `You're now Level ${data?.new_level || 2} — ${data?.level_title || "Green Sprout"}! 🌟`;
    case "badge_earned":
      return `You earned the "${data?.badge_name || "Special Badge"}" badge! Check your profile.`;
    case "weekly_summary":
      return `Your week in review: ${data?.co2_saved || 0} kg CO₂ saved, ${data?.streak || 0} days active.`;
    case "leaderboard_overtaken":
      return `${data?.overtaker_name || "Someone"} just overtook you on the leaderboard!`;
    case "quiz_available":
      return `Test your eco knowledge and earn up to ${data?.xp || 130} XP!`;
    default:
      return "Check your progress!";
  }
}
