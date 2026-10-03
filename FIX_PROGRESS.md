# NeutraWise Fix Progress

Supabase project: psztwkbfhwehmesschbk (changes applied directly to main; no live users).
Verification: `flutter test` and `dart analyze` could NOT be run in the assistant sandbox (Dart SDK host blocked). Run both locally after applying each phase patch.

## Phases (highest priority first)
- [x] **Phase 1 – Dead features:** badges schema/code mismatch, quiz parent-row save, notification-pref key mismatch. (migration `20261003155138`)
- [x] **Phase 2 – Data exposure & privileges:** `users`/`daily_logs` now own-row only; leaderboard served by `get_leaderboard` RPC; anon revoked; TRUNCATE/REFERENCES/TRIGGER revoked; catalog tables read-only; users DELETE policy added (account deletion). (migration `20261003213124`). Deferred: quiz answer visibility -> Phase 4.
- [ ] **Phase 3 – Challenges actually complete:** server-side daily audit (pg_cron) + completion/XP award; fix evaluate/audit flow.
- [ ] **Phase 4 – Server-side XP/streak integrity:** SECURITY DEFINER RPCs for log/quiz submit; idempotent milestones; restrict direct XP/streak/level writes; server date.
- [ ] **Phase 5 – Calculation bugs:** logged transport mode factor; unconfirmed-energy handling; spec alignment.
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
