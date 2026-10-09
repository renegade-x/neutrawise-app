# Migrations

Files `001`-`012` were applied first and are recorded in the remote history under those short
numbers; they must NOT be renamed (renaming desyncs `supabase db push`). Everything newer uses
the `YYYYMMDDHHMMSS_name.sql` form. Add new migrations only with the timestamp form.

Older files that mention `https://your-project.supabase.co`, `app.jwt_secret` or the original
public `USING (true)` policies are historical: they are superseded by the phase migrations
(`20261003*`, `20261004*`, `20261006*`). Do not copy SQL out of them.

Regression tests: `supabase/tests/regression.sql` (rolls back; see the header for how to run).
