# 🌿 NeutraWise

## Gamification System Design

*XP · Levels · Challenges · Badges · Streaks · Leaderboard · Quizzes · Push Notifications*

# 1. XP (Experience Points) System

XP is the core currency of engagement in NeutraWise. Every positive eco-action a user takes earns XP, which feeds into their level, leaderboard rank, and unlock system. The design philosophy is: reward consistency first, depth second.

## 1.1  XP Earning Activities — Full Table

| **Activity** | **Base XP** | **Multiplier / Condition** | **Notes** |
| --- | --- | --- | --- |
| Daily Activity Logging (complete) | **50 XP** | ×1.5 on streak ≥ 7 days | All 3 categories logged: Transport, Food, Energy |
| Partial Activity Log (1–2 categories) | 20 XP | No multiplier | Encourages logging anything over nothing |
| Flashcard Quiz Attempt (Bi-weekly) | **30 XP** | Bonus: +5 XP per correct answer | Max 10 questions per quiz session. Quiz is optional. |
| Perfect Quiz Score (10/10) | +50 XP bonus | Stacks with attempt XP | Rare bonus to reward mastery |
| Challenge Completion (Easy) | **100 XP** |  | E.g. Log meals for 3 days straight |
| Challenge Completion (Medium) | **200 XP** |  | E.g. No car for 5 days |
| Challenge Completion (Hard) | **400 XP** |  | E.g. Carbon-neutral week, Plant a tree |
| Streak Milestone (7 days) | +75 XP bonus | One-time per milestone | Shown with celebratory animation |
| Streak Milestone (30 days) | **+300 XP bonus** | One-time per milestone | Major milestone badge trigger |
| Streak Milestone (100 days) | **+1000 XP bonus** | One-time per milestone | Legendary badge trigger |

*💡 Daily cap: 500 XP per day from logging + quizzes combined. Challenge XP is uncapped and applied separately.*

## 1.2  XP Formula

**Final XP = (Base XP + Bonus XP) × Streak Multiplier × Level Multiplier**

| **Variable** | **Value** | **Condition** |
| --- | --- | --- |
| Streak Multiplier | ×1.0 / ×1.25 / ×1.5 | Streak 1–6 / 7–29 / 30+ days |
| Level Multiplier | ×1.0 / ×1.1 / ×1.2 | Levels 1–4 / 5–8 / 9+ |

# 2. Level System

Levels provide a sense of long-term progression. They unlock cosmetic rewards, challenge slots, and communicate eco-identity to the community.

| **Lvl** | **Title** | **Total XP Required** | **XP to Next Level** | **Unlocks** |
| --- | --- | --- | --- | --- |
| **1** | **Eco Newcomer** | 0 (Start) | 500 | Basic daily log, 1 active challenge slot |
| **2** | **Green Sprout** | 500 | 1000 | Activity log history, streak tracker |
| **3** | **Eco Explorer** | 1,500 | 1500 | Insights screen, monthly targets |
| **4** | **Sustainability Seeker** | 3,000 | 2000 | 2 active challenge slots, global leaderboard |
| **5** | **Eco Advocate** | 5,000 | 3000 | Badge showcase, quiz bonus XP |
| **6** | **Climate Champion** | 8,000 | 4000 | 3 active challenge slots, hard challenges unlock |
| **7** | **Green Guardian** | 12,000 | 5000 | Custom profile themes |
| **8** | **Eco Hero** | 17,000 | 6000 | Friends leaderboard, challenge creation (future) |
| **9** | **Carbon Crusader** | 23,000 | 8000 | Legacy badge, 4 active challenge slots |
| **10** | **Carbon Neutral** | 31,000 | — | Champion badge, permanent leaderboard star |

*💡 XP requirements use a progressive curve: each level costs roughly 20–30% more XP than the previous one. This keeps early levels fast and rewarding while making higher levels feel earned.*

# 3. Streak System

The streak is the primary daily retention mechanic. A streak is maintained by completing a full or partial activity log each calendar day. Missing a day resets the streak to zero.

## 3.1  Streak Rules

- A streak increments by +1 for each calendar day the user logs activity (at least 1 category).

- A full log (all 3 categories) is required for the streak multiplier bonus to apply.

- The streak resets to 0 if no log entry is made before midnight (user's local timezone).

- A 'Streak Freeze' power-up (earned at Level 4, max 1 held at a time) can protect the streak for 1 missed day.

- Streaks are displayed prominently on the dashboard and profile screen.

## 3.2  Streak Milestones & Rewards

| **Streak** | **Bonus XP** | **Badge Earned** | **Other Reward** |
| --- | --- | --- | --- |
| **3 days** | **+25 XP** | — | Streak fire icon activates on dashboard |
| **7 days** | **+75 XP** | Week Warrior 🔥 | Push notification: 'One whole week — you're on fire!' |
| **14 days** | **+150 XP** | Fortnight Fighter 💪 | Streak shown on leaderboard card |
| **30 days** | **+300 XP** | Monthly Maven 🌿 | Streak Freeze power-up awarded |
| **60 days** | **+600 XP** | Eco Consistent 🌍 | Gold streak border on profile |
| **100 days** | **+1000 XP** | Century Eco 🏆 | Legendary badge, permanent profile flair |

## 3.3  Streak Expiration Warning — Push Notification Logic

- A warning notification is sent at 8:00 PM local time if the user has not logged activity that day.

- A final warning is sent at 10:30 PM if still no log has been submitted.

- Message tone: encouraging, not guilt-inducing — e.g. 'Your 14-day streak is at risk! Log anything to keep it alive 🌿'

# 4. Challenges System

Challenges are time-bound missions that drive meaningful behaviour change. They are organised by category, and completing a set number in a category unlocks that category's badge. Users can hold multiple challenges simultaneously (based on their level).

## 4.1  Challenge Structure

| **Field** | **Description** |
| --- | --- |
| **Name** | Short, action-oriented title (e.g. 'No Car Week') |
| **Category** | Transport / Food / Energy / Lifestyle / Nature |
| **Difficulty** | Easy / Medium / Hard |
| **Duration** | How many days/weeks the challenge runs |
| **Completion Criteria** | Specific verifiable condition (logged via daily activity) |
| **XP Reward** | 100 / 200 / 400 XP for Easy / Medium / Hard |
| **Badge Progress** | +1 count toward the category badge |
| **Progress Tracking** | Percentage bar shown on Gamification screen |

## 4.2  Challenge Library — Transport Category 🚗

| **Challenge Name** | **Difficulty** | **Duration** | **XP** | **Completion Criteria** |
| --- | --- | --- | --- | --- |
| **No Car Day** | **Easy** | 1 day | **100 XP** | Log 0 km in private car for the day |
| **No Car Weekend** | **Easy** | 2 days | **100 XP** | Zero private car use over Sat–Sun |
| **Cycle to Work Week** | **Medium** | 5 days | **200 XP** | Log cycling as transport mode for 5 workdays |
| **No Car Week** | **Medium** | 7 days | **200 XP** | Log no private car usage for 7 consecutive days |
| **Public Transport Month** | **Hard** | 30 days | **400 XP** | Use only public transit / cycling / walking for 30 days |
| **Walk 10,000 Steps Daily** | **Easy** | 7 days | **100 XP** | Log walking as primary transport for 7 days |
| **Carpool Champion** | **Medium** | 5 days | **200 XP** | Log shared rides 5 times in a week |

## 4.3  Challenge Library — Food Category 🥗

| **Challenge Name** | **Difficulty** | **Duration** | **XP** | **Completion Criteria** |
| --- | --- | --- | --- | --- |
| **Meatless Monday** | **Easy** | 1 day | **100 XP** | Log no meat in meals on Monday |
| **Plant-Based Week** | **Medium** | 7 days | **200 XP** | Log vegan/vegetarian meals for 7 days |
| **Zero Food Waste Day** | **Easy** | 1 day | **100 XP** | Log no food waste in daily entry |
| **Local Foods Fortnight** | **Medium** | 14 days | **200 XP** | Log only locally-sourced foods for 2 weeks |
| **Vegan Challenge** | **Hard** | 30 days | **400 XP** | Log fully plant-based diet for 30 days |
| **Cut Single-Use Plastics** | **Easy** | 7 days | **100 XP** | Log use of reusable containers for 7 days |
| **Meal Prep Master** | **Medium** | 5 days | **200 XP** | Log home-cooked meals for 5 consecutive days |

## 4.4  Challenge Library — Energy Category ⚡

| **Challenge Name** | **Difficulty** | **Duration** | **XP** | **Completion Criteria** |
| --- | --- | --- | --- | --- |
| **Unplug Day** | **Easy** | 1 day | **100 XP** | Log no standby devices for the day |
| **Cold Shower Week** | **Easy** | 7 days | **100 XP** | Log cold or short showers for 7 days |
| **No AC Week** | **Medium** | 7 days | **200 XP** | Log zero air conditioning use for 7 days |
| **LED Switch Challenge** | **Easy** | 1 day | **100 XP** | Log replacement of all bulbs with LEDs |
| **Energy Fast Weekend** | **Medium** | 2 days | **200 XP** | Reduce home energy use by 50% over a weekend |
| **Solar/Renewable Pledge** | **Hard** | 30 days | **400 XP** | Log use of renewable energy source for 30 days |
| **Screen Time Cutback** | **Easy** | 7 days | **100 XP** | Log <2 hours screen time daily for 7 days |

## 4.5  Challenge Library — Nature Category 🌳

| **Challenge Name** | **Difficulty** | **Duration** | **XP** | **Completion Criteria** |
| --- | --- | --- | --- | --- |
| **Plant a Tree** | **Medium** | One-time | **200 XP** | Upload photo proof of tree planting |
| **Litter Pickup Walk** | **Easy** | 1 day | **100 XP** | Log community cleanup activity |
| **Start a Compost Bin** | **Medium** | One-time | **200 XP** | Log compost setup, mark as complete |
| **Go Paperless** | **Easy** | 7 days | **100 XP** | Log zero paper use for 7 days |
| **Community Garden Day** | **Easy** | 1 day | **100 XP** | Log participation in community growing |
| **Ocean/Park Cleanup** | **Medium** | One-time | **200 XP** | Log participation in organised cleanup |
| **100-Day Green Journey** | **Hard** | 100 days | **400 XP** | Maintain active use of app for 100 days |

## 4.6  Challenge Library — Lifestyle Category 🌀

| **Challenge Name** | **Difficulty** | **Duration** | **XP** | **Completion Criteria** |
| --- | --- | --- | --- | --- |
| **Secondhand Shopping Week** | **Easy** | 7 days | **100 XP** | Log all clothing from secondhand sources |
| **Buy Nothing Day** | **Easy** | 1 day | **100 XP** | Log zero new purchases for the day |
| **Digital Detox Day** | **Easy** | 1 day | **100 XP** | Log <1 hr screen time in a day |
| **Zero Waste Week** | **Hard** | 7 days | **400 XP** | Log producing <200g waste per day for 7 days |
| **Eco-Gifting Challenge** | **Medium** | One-time | **200 XP** | Log gifting an eco-friendly / experience-based gift |
| **Capsule Wardrobe Month** | **Hard** | 30 days | **400 XP** | Log wearing only 10 clothing items for 30 days |
| **Support Local Week** | **Medium** | 7 days | **200 XP** | Log exclusively local business purchases |

*💡 Challenge progress is verified through the daily activity log. The app cross-references the log data against the challenge criteria automatically. Photo proof is required only for Nature challenges marked 'One-time'.*

# 5. Badge System

Badges are permanent achievements displayed on the user's profile. They serve as social proof of eco-commitment and are earned by completing a set number of challenges within a category, hitting streak milestones, or reaching level thresholds.

## 5.1  Category Badges — Earned by Challenge Completions

| **Category** | **Badge Name** | **Bronze (3 challenges)** | **Silver (7 challenges)** | **Gold (12 challenges)** | **Badge Description** |
| --- | --- | --- | --- | --- | --- |
| **🚗 Transport** | **Road to Green** | 🥉 | 🥈 | 🥇 | Awarded for reducing transport emissions |
| **🥗 Food** | **Conscious Plate** | 🥉 | 🥈 | 🥇 | Awarded for sustainable eating habits |
| **⚡ Energy** | **Power Saver** | 🥉 | 🥈 | 🥇 | Awarded for reducing home energy use |
| **🌳 Nature** | **Nature Keeper** | 🥉 | 🥈 | 🥇 | Awarded for active nature preservation |
| **🌀 Lifestyle** | **Mindful Consumer** | 🥉 | 🥈 | 🥇 | Awarded for sustainable living choices |

## 5.2  Special Badges

| **Badge** | **Trigger** | **Description** |
| --- | --- | --- |
| **Week Warrior 🔥** | 7-day streak | Consistent eco-logger for a full week |
| **Monthly Maven 🌿** | 30-day streak | A month of daily sustainability tracking |
| **Century Eco 🏆** | 100-day streak | Legendary dedication to the eco cause |
| **Quiz Whiz 🧠** | 5 perfect quiz scores | Sustainability knowledge champion |
| **Eco Newcomer ✨** | First activity log | Welcome to the journey badge |
| **All-Rounder 🌐** | 1 challenge per category | Completed challenges in all 5 categories |
| **Carbon Neutral 🌍** | Reach Level 10 | The ultimate NeutraWise achievement |
| **Leaderboard Leader 👑** | Rank #1 for a full month | Topped the monthly leaderboard |
| **Streak Saver 🛡️** | Use a Streak Freeze | Used the streak freeze power-up |

*💡 Badges are visible on the user's public profile card and appear in the leaderboard alongside the username. Earning a new badge triggers a full-screen celebration animation.*

# 6. Leaderboard System

The leaderboard ranks users by XP, creating healthy competition and social accountability. It resets on a monthly cycle to give all users a fair chance each season.

## 6.1  Leaderboard Tiers

| **Tier** | **Scope** | **Reset Period** | **Eligibility** |
| --- | --- | --- | --- |
| **Global 🌍** | All app users | Monthly (1st of each month) | All users |
| **Friends 👥** | Mutual follow network | Monthly | Level 5+ unlock |
| **City 🏙️** | Same city/region | Monthly | City set in profile |
| **Weekly Sprint ⚡** | All users | Weekly (Monday reset) | All users — shorter cycle for extra engagement |

## 6.2  Monthly Leaderboard Rewards

| **Rank** | **Bonus XP** | **Reward** |
| --- | --- | --- |
| **#1 🥇** | **+500 XP** | 'Leaderboard Leader' badge + champion crown on profile |
| **#2 🥈** | **+300 XP** | Silver leaderboard badge for the month |
| **#3 🥉** | **+200 XP** | Bronze leaderboard badge for the month |
| **Top 10 🏅** | **+100 XP** | Top 10 flair on profile card |
| **Top 25%** | **+50 XP** | Motivational push notification acknowledging their ranking |

## 6.3  Leaderboard Overtake Push Notification

- Triggered when any user surpasses the current user's XP rank.

- Sent immediately (real-time or near real-time, max 15-minute delay).

- Example message: "Ahmad just overtook you on the leaderboard! You're now #14. Log today's activity to climb back up 🌿"

- Frequency cap: max 3 overtake notifications per day to prevent notification fatigue.

- User can mute overtake notifications in settings.

# 7. Flashcard Quiz System

The quiz system is a bi-weekly optional engagement mechanic that reinforces sustainability knowledge and earns bonus XP. Quizzes are delivered via push notification and accessible for a 48-hour window.

## 7.1  Quiz Mechanics

| **Property** | **Value** |
| --- | --- |
| **Frequency** | Twice per week (e.g., Tuesday & Friday) |
| **Availability** | 48-hour window from notification time |
| **Questions** | 10 questions per session (multiple choice, 4 options) |
| **Time limit** | No time pressure — casual, learn-at-own-pace format |
| **Attempts** | 1 attempt per quiz session (no retries) |
| **Base XP** | 30 XP for attempting the quiz |
| **Per-question** | +5 XP per correct answer (max +50 XP) |
| **Perfect score** | Additional +50 XP bonus (so max 30+50+50 = 130 XP total) |
| **Topics** | Rotating: Transport, Food, Energy, Nature, Climate Science, Eco Tips |

## 7.2  Sample Question Bank — Transport

**Q1: Which vehicle type produces the least CO₂ per km?**

- A. Petrol car

- B. Diesel car

- C. Electric vehicle ✅

- D. Motorcycle

**Q2: Approximately how many kg of CO₂ does a long-haul flight emit per passenger per hour?**

- A. 5 kg

- B. 90 kg ✅

- C. 250 kg

- D. 1,000 kg

**Q3: What is 'carpooling' most effective at reducing?**

- A. Fuel cost only

- B. Per-person carbon emissions ✅

- C. Wear on roads

- D. Travel time

## 7.3  Sample Question Bank — Food

**Q4: Which food has the highest carbon footprint per 100g?**

- A. Lentils

- B. Chicken

- C. Beef ✅

- D. Tofu

**Q5: What does 'food miles' refer to?**

- A. Calories burned cooking

- B. Distance food travels from farm to plate ✅

- C. Amount of food wasted

- D. Nutritional value

**Q6: Eating seasonally helps reduce emissions because:**

- A. It tastes better

- B. Local seasonal food needs less transport and refrigeration ✅

- C. Seasonal food is cheaper

- D. It has fewer calories

## 7.4  Sample Question Bank — Energy

**Q7: Which household appliance typically uses the most energy?**

- A. LED bulb

- B. Laptop

- C. Refrigerator ✅

- D. Phone charger

**Q8: What does 'phantom load' mean?**

- A. Energy lost in transit

- B. Electricity used by devices on standby ✅

- C. Peak usage hours

- D. Solar panel loss

**Q9: Lowering your thermostat by 1°C can reduce heating bills by approximately:**

- A. 0.5%

- B. 10% ✅

- C. 30%

- D. 50%

## 7.5  Sample Question Bank — Climate Science

**Q10: The main greenhouse gas produced by human activity is:**

- A. Oxygen

- B. Methane

- C. CO₂ ✅

- D. Nitrogen

*💡 The full question bank should contain at least 100 questions per topic to prevent repetition. Questions are randomly selected for each session. After completing the quiz, the app shows an explanation card for each correct/incorrect answer.*

# 8. Push Notification System

Notifications are the bridge between the app and the user's daily life. All notifications follow the brand tone: encouraging, friendly, never guilt-inducing. Users can customise which notifications they receive in Settings.

## 8.1  Notification Schedule & Templates

| **Type** | **Trigger** | **Timing** | **Example Message** |
| --- | --- | --- | --- |
| **Daily Log Reminder** | No log by 8PM | 8:00 PM local | 🌿 How was your day? Log your activity and keep your streak alive! |
| **Final Log Warning** | No log by 10:30PM | 10:30 PM local | ⚠️ Last chance to log today! Don't break your [N]-day streak 🔥 |
| **Streak Expiration** | Streak > 0, no log | 10:30 PM | Your [N]-day streak expires at midnight. Log anything now to save it! |
| **Streak Milestone** | Streak hits milestone | Immediately | 🔥 [N] days in a row! You're a true eco-warrior. +[XP] XP awarded! |
| **Challenge Reminder** | Challenge in progress, not logged | Daily 12 PM | 📋 Day [X] of your '[Challenge]' challenge. You've got this! |
| **Challenge Complete** | All criteria met | Immediately | 🎉 Challenge complete! '[Challenge]' done. +[XP] XP earned and badge progress updated! |
| **Leaderboard Overtaken** | User surpassed in rank | Within 15 min | [Name] just overtook you! You're now #[rank]. Climb back up 💪 |
| **New Quiz Available** | Bi-weekly schedule | Tue & Fri 9 AM | 🧠 New quiz available for 48hrs! Test your eco knowledge and earn up to 130 XP — optional but fun! |
| **Badge Earned** | Badge trigger met | Immediately | 🏅 New badge unlocked: '[Badge Name]'! Check your profile to see it. |
| **Level Up** | XP threshold crossed | Immediately | ⬆️ Level up! You're now a [Level Title]. New features unlocked 🌍 |
| **Weekly Summary** | Every Sunday 6 PM | Sunday 6 PM | 📊 Your week in review: [X] kg CO₂ saved, [streak] days, [XP] earned. Keep it up! |

## 8.2  Notification Preferences (User-Controlled)

- Daily log reminder: ON by default

- Streak warnings: ON by default

- Challenge reminders: ON by default

- Leaderboard overtake: ON by default (max 3/day cap)

- Quiz notifications: ON by default

- Badge & level-up: ON by default (cannot be disabled — celebratory, non-disruptive)

- Weekly summary: ON by default

*💡 All notification times are in the user's local timezone. Users can set a custom 'quiet hours' window in Settings where non-urgent notifications are held.*

# 9. System Summary & Daily Engagement Loop

The gamification system is designed around a tight daily loop that rewards consistent, meaningful eco-behaviour. Here is the intended user journey:

| **#** | **Action** | **Outcome** |
| --- | --- | --- |
| **1** | **Open app** | Dashboard shows daily CO₂ score, streak counter, in-progress challenges |
| **2** | **Log daily activity** | Earns 20–50 XP. Streak maintained. Challenge progress updated automatically. |
| **3** | **Check Gamification tab** | View level progress, active challenges, badge collection, leaderboard rank |
| **4** | **Attempt bi-weekly quiz (optional)** | Earns up to 130 XP. Shown for 48 hrs. Sent via push notification. |
| **5** | **Complete a challenge** | Earns 100–400 XP. Badge progress +1. Celebration animation plays. |
| **6** | **Check leaderboard** | See position, get motivated or competitive. Overtake notifications keep users engaged. |
| **7** | **Earn a badge or level up** | Full-screen animation. Profile updated. Push notification sent. |

---

*NeutraWise — Gamification System Design | Version 1.0*