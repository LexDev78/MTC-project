/// Supabase Auth is email-centric, but this app logs in with a plain
/// `usernameOrPhone` (never an email). This synthesizes a deterministic,
/// internal-only email from it — never shown to the user, only ever used as
/// the `email` argument to `signUp`/`signInWithPassword`. Also gives
/// "username already taken" for free via `auth.users.email`'s unique
/// constraint (see `handle_new_user()`, `supabase/migrations/0001_initial_schema.sql`).
String pseudoEmail(String usernameOrPhone) {
  return '${usernameOrPhone.trim().toLowerCase()}@mtc.local';
}
