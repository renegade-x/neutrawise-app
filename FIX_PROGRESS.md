# NeutraWise Fix Progress

Supabase project: psztwkbfhwehmesschbk (changes applied directly to main; no live users).
Verification: `flutter test` and `dart analyze` could NOT be run in the assistant sandbox (Dart SDK host blocked). Run both locally after applying each phase patch.

## Phases (highest priority first)
- [x] **Phase 1 – Dead features:** badges schema/code mismatch, quiz parent-row save, notification-pref key mismatch. (migration `20261003155138`)
- [ ] **Phase 2 – Data exposure & privileges:** replace public `users`/`daily_logs` SELECT with leaderboard RPC/view; revoke unneeded anon/authenticated grants (TRUNCATE etc.); remove overlapping catalog policies; hide quiz answers.
- [ ] **Phase 3 – Challenges actually complete:** server-side daily audit (pg_cron) + completion/XP award; fix evaluate/audit flow.
- [ ] **Phase 4 – Server-side XP/streak integrity:** SECURITY DEFINER RPCs for log/quiz submit; idempotent milestones; restrict direct XP/streak/level writes; server date.
- [ ] **Phase 5 – Calculation bugs:** logged transport mode factor; unconfirmed-energy handling; spec alignment.
- [ ] **Phase 6 – Push infrastructure:** pg_net/pg_cron, deploy edge function (JWT verified), replace placeholder URLs, trigger search_path.
- [ ] **Phase 7 – Hygiene:** untrack supabase/.temp, .gitignore .env, migration naming, indexes (users.xp/city), avatars to Storage, deep-link scheme, release signing, leaked-password protection.
- [ ] **Phase 8 – Tests/a11y/observability.**

## Phase 1 changes
- DB: `badges` gets `category`, unique `(user_id, badge_name)`; `quizzes` defaults for NOT NULL columns; `notification_preferences` gets edge-function key columns kept in sync by trigger.
- Code: `awardBadge` writes `badge_tier`/`category`, inserts once and only upgrades tier; `quiz_repository` parent-row upsert includes required fields, Quiz Whiz badge uses `badge_tier`.
