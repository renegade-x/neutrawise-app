# NeutraWise Fix Progress

Supabase project: psztwkbfhwehmesschbk (changes applied directly to main; no live users).
Verification: `flutter test` and `dart analyze` could NOT be run in the assistant sandbox (Dart SDK host blocked). Run both locally after applying each phase patch.

## Phases (highest priority first)
- [x] **Phase 1 – Dead features:** badges schema/code mismatch, quiz parent-row save, notification-pref key mismatch. (migration `20261003155138`)
- [x] **Phase 2 – Data exposure & privileges:** `users`/`daily_logs` now own-row only; leaderboard served by `get_leaderboard` RPC; anon revoked; TRUNCATE/REFERENCES/TRIGGER revoked; catalog tables read-only; users DELETE policy added (account deletion). (migration `20261003213124`). Deferred: quiz answer visibility -> Phase 4.
- [x] **Phase 3 – Challenges actually complete:** idempotent catch-up audit (`auditPendingChallenges`), `challenge_completions` table created, re-enroll fixed, completion XP claimed once. (migration `20261003213756`).
- [x] **Phase 4 – Server-side XP/streak integrity:** `submit_log_rewards` + `award_xp` RPCs, `xp_ledger`, column-level lockdown of XP/level/streak columns. (migration `20261004062723`)
- [x] **Phase 5 – Calculation bugs:** logged transport mode factor; unconfirmed energy counts baseline; energy confirmation no longer inferred from CO2 > 0. (code only)
- [ ] **Phase 6 – Push infrastructure:** pg_net/pg_cron, deploy edge function (JWT verified), replace placeholder URLs, trigger search_path.
- [ ] **Phase 7 – Hygiene:** untrack supabase/.temp, .gitignore .env, migration naming, indexes (users.xp/city), avatars to Storage, deep-link scheme, release signing, leaked-password protection.
- [ ] **Phase 8 – Tests/a11y/observability.**

## Phase 1 changes
- DB: `badges` gets `category`, unique `(user_id, badge_name)`; `quizzes` defaults for NOT NULL columns; `notification_preferences` gets edge-function key columns kept in sync by trigger.
- Code: `awardBadge` writes `badge_tier`/`category`, inserts once and only upgrades tier; `quiz_repository` parent-row upsert includes required fields, Quiz Whiz badge uses `badge_tier`.

## Phase 2 changes
- DB: `get_leaderboard(p_type, p_city, p_limit)` SECURITY DEFINER (authenticated only) returns name/avatar/xp/level/rank for global, city, weekly_sprint. Own-row SELECT on `users` and `daily_logs`. DELETE policy on `users`. Anon has no table access. Catalog tables (badge_catalog, challenges, pakistani_foods, question_bank, quiz_questions, leaderboard_rankings) are read-only for clients.
- Code: `LeaderboardRepository.getLeaderboard` calls the RPC (weekly sprint now aggregated server-side; empty sprint still falls back to global; friends still falls back to global).
- Verified in a rolled-back DB test as `authenticated`: own rows only (1 user, 14 logs), leaderboard returns both users, TRUNCATE and catalog writes denied, anon denied.
- Known leftovers: advisor warnings for notify_* search_path (Phase 6), leaked-password protection (Phase 7). Account deletion removes the `users` row only; the auth user remains (Phase 7).

## Phase 3 changes
- DB: `user_challenges.last_audited_date`; new `challenge_completions` table (RLS: own rows, select+insert) - the code already wrote to it but it never existed.
- Code: `performMidnightAudit` (no callers) replaced by `auditPendingChallenges`, which settles every fully-elapsed day since the last audit (idempotent via `last_audited_date`), runs on dashboard open and after each log save. Pure logic in `domain/gamification/challenge_audit.dart` with unit tests (`test/domain/gamification/challenge_audit_test.dart`).
- Fixes: re-enrolling now upserts on `(user_id, challenge_id)` (was a unique-violation); `evaluateChallengesForUser` no longer marks runs failed early; window expiry is by calendar days; completion count comes from `challenge_completions` (the column default of 1 made the first completion count as the second and decayed XP); completion is claimed with `status = in_progress` so XP is paid once even with two devices.
- Known leftover: challenge XP is still a client read-modify-write on `users` (moved server-side in Phase 4). Dates still use device time (Phase 4).

## Phase 4 changes
- DB: `xp_ledger` (unique per user/source/key; backfilled from existing daily logs); `_level_for_xp`; internal `_apply_xp` (not callable by clients); `submit_log_rewards(p_date, p_is_full_log, p_log_xp, p_co2_saved_delta)` and `award_xp(p_source, p_key, p_amount)` (SECURITY DEFINER, authenticated only).
- `users`: clients can no longer INSERT/UPDATE `xp`, `lifetime_xp`, `monthly_xp`, `level`, any streak column, `days_active`, `total_co2_saved` (column-level grants). Direct PATCH of `xp` is rejected.
- Server rules: log date must be within +-1 day of server date; log XP capped (130 full / 24 partial) and replaced per date on re-save; milestone XP (3/7/14/30/60/100 days) paid once; a streak freeze covers exactly one missed day (was: any gap); quiz XP once per quiz (cap 130); challenge XP once per completion and only for a completed challenge (cap 400); CO2-saved delta bounded to +-200 kg.
- Code: `UserRepository.submitLogRewards/awardXp`, `editableProfileJson` (saveUserProfile no longer sends server-managed columns, the PGRST204 fallbacks are removed); `_submitLog` uses one RPC instead of ~6 client writes; quiz and challenge XP use `award_xp`.
- Streak counting rule is unchanged: the first log counts 0, the second consecutive day 1 (it is an intentional rule covered by existing tests, so the audit note about it being "one behind" was withdrawn). To change it, edit the `v_last IS NULL` branch and the `+1` logic in `submit_log_rewards` plus `calculateStreakFromLogDates`.
- Known limits: the daily-log contents (and so XP inputs) are still computed on the client and only range-checked; challenge qualification flags are client-written; quiz answers are still readable by clients; rewards need a connection (an offline log saves but XP/streak apply only if the app is online at submit time - offline reward sync belongs to Phase 8).

## Phase 5 changes
- `CO2Calculator`: private-vehicle trips (car/ev/motorcycle) use the profile factor only when that is the user's registered vehicle; otherwise a sensible default for the mode. Unconfirmed energy now uses the baseline (was 0, which made partial logs look far below baseline). `GamificationEngine.isEnergyConfirmed` now requires an explicit confirmation or a deviation (it used to treat energy CO2 > 0 as confirmed, which would now always be true).
- Tests: new transport-mode tests, updated partial-log expectation, `energy_confirmation_test.dart`, `profile_save_columns_test.dart`.
