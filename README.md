# NeutraWise

NeutraWise is a gamified eco-habit tracker built with Flutter, Riverpod, Hive, and Supabase. It helps users log their daily transport, food, and energy habits to reduce their carbon footprint while competing on leaderboards and earning badges!

## Current Development Status
- **Completed:** Phase 1 (Architecture), Phase 2 (Auth/Onboarding), Phase 3 (Dashboard & Activity Logging offline-first).
- **In Progress:** Phase 4 (Gamification & Insights).

---

## 🛠️ Developer Setup Guide

Follow these steps to set up the project on your local machine.

### 1. Prerequisites
- **Flutter SDK:** Version 3.16.0 or higher.
- **Dart SDK:** Version 3.2.0 or higher.
- **Git:** Version control.
- An active Supabase Cloud account (with a project created).

### 2. Clone the Repository
```bash
git clone <repository_url>
cd neutrawise-app
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Setup Environment Variables (`.env`)
You must configure your Supabase environment variables before running the app. 
1. Create a `.env` file in the root of the project (same directory as `pubspec.yaml`).
2. Add the following keys from your Supabase Dashboard (`Settings -> API`):

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-long-anon-key-here
```
> ⚠️ **Note:** Do not commit the `.env` file to version control. It is ignored in `.gitignore`.

### 5. Generate Code (Freezed & Riverpod)
We heavily rely on `freezed` and `riverpod_generator`. Any time you pull new code or change models/providers, you must run the build runner!

```bash
# Run this once:
dart run build_runner build --delete-conflicting-outputs

# Or leave this running in the background while developing:
dart run build_runner watch --delete-conflicting-outputs
```

### 6. Run the App
You are now ready to launch the app!
```bash
flutter run
```

---

## 🏗️ Architecture Notes for Team Members
- **State Management:** Riverpod 3.x. Check `lib/providers/` for global providers.
- **Data Models:** Always use `Freezed` for models inside `lib/domain/models/`. You must run `build_runner` to generate the `.freezed.dart` and `.g.dart` files.
- **Offline-First Sync:** We use `Hive` in `lib/data/sync/sync_manager.dart` to queue activity logs. Do NOT query Supabase `daily_logs` directly for writing; instead use `ref.read(syncManagerProvider).saveLog(log)` to ensure resilient offline syncing.
- **Supabase Realtime:** Realtime subscriptions must be enabled manually in the Supabase Dashboard for the `daily_logs` table under `Database -> Replication`.

## 📜 Documentation
- `DEVELOPMENT_PROGRESS.md`: Tracks what is done and what is pending.
- `NeutraWise_Algorithm_Specification_v1.0.md`: Single source of truth for the CO₂ math and XP gamification logic.
- `gap_analysis.md`: Explains critical architectural decisions (e.g. why we use optimistic UI for logs).
