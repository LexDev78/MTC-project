import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// `flutter test` installs a fake [HttpOverrides] on every test file it
/// runs (not just `testWidgets` ones) that makes every real HTTP request
/// fail instantly with an empty 400 — a deliberate sandbox against
/// accidental network calls in ordinary unit tests. `integration`-tagged
/// tests need the opposite: real requests to the local Supabase stack.
/// Idempotent, so calling it from every test's `setUp`/`resetAndSeed()`
/// (see below) is harmless.
void _allowRealHttpRequests() {
  HttpOverrides.global = null;
}

/// Connection info for the local Supabase stack started by `supabase
/// start` (see BACKEND_MIGRATION_PROGRESS.md, Lot 0). These are the
/// well-known fixed local-dev keys the Supabase CLI derives from the
/// equally-fixed local `JWT_SECRET` — not secrets in any meaningful sense,
/// safe to commit, and re-displayable at any time via `supabase status`.
const _supabaseUrl = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

/// A fresh, session-less client — one per test, exactly what
/// `supabaseClientProvider` is overridden with in every `integration`-tagged
/// test. Plain `package:supabase` (not `supabase_flutter`) since tests don't
/// need `Supabase.initialize()`'s Flutter-specific local-storage session
/// persistence — each test starts signed out and logs in itself.
SupabaseClient createTestSupabaseClient() {
  _allowRealHttpRequests();
  return SupabaseClient(
    _supabaseUrl,
    _anonKey,
    authOptions: const AuthClientOptions(
      // Tests are short-lived and never outlive a single test body — a
      // periodic auto-refresh `Timer` would otherwise trip
      // `flutter_test`'s "no pending timers after the test" invariant.
      autoRefreshToken: false,
      // The default PKCE flow needs `pkceAsyncStorage` to persist a code
      // verifier across the redirect step — `Supabase.initialize()` wires
      // that up automatically in the real app (`bootstrap.dart`), but a
      // bare `SupabaseClient` doesn't, and this app has no OAuth/deep-link
      // flow to begin with (only email+password). Without this,
      // `signUp()` throws `_asyncStorage != null` before ever reaching
      // the network.
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

/// `service_role` bypasses RLS entirely — this is the only client allowed
/// to call `test_reset_and_seed()` (see
/// `supabase/migrations/0002_test_reset_fn.sql`, `grant execute ... to
/// service_role`). Reused across the whole test run; it never signs in, so
/// there's no session to reset between tests.
final _adminClient = SupabaseClient(_supabaseUrl, _serviceRoleKey);

/// Truncates every application table and replays the demo dataset (see
/// `test_reset_and_seed()`) — call in `setUp` so each test starts from the
/// exact same fixture, regardless of what a previous test mutated. Requires
/// `supabase start` to be running locally (see BACKEND_MIGRATION_PROGRESS.md).
Future<void> resetAndSeed() async {
  _allowRealHttpRequests();
  await _adminClient.rpc('test_reset_and_seed');
}

/// Directly adjusts a product's stock, bypassing RLS via
/// `test_adjust_stock()` (`0004_test_admin_helpers.sql`) — for staging a
/// scenario (e.g. "already out of stock") that no real user session could
/// ever legitimately produce for a product they don't own. `service_role`
/// has no direct table grants of its own (see `0001_initial_schema.sql`,
/// section 6) so this must go through a `security definer` RPC, same as
/// `resetAndSeed()`. Not a substitute for `productRepository.adjustStock`,
/// which real code and most tests should keep going through.
Future<void> adjustStockAsAdmin({
  required String productId,
  required int quantityDelta,
}) async {
  await _adminClient.rpc(
    'test_adjust_stock',
    params: {'p_product_id': productId, 'p_quantity_delta': quantityDelta},
  );
}

/// Reads a product's stock movement ledger, bypassing RLS — that ledger is
/// private to the owning supplier (`stock_movements_all_own_product`), so a
/// test acting as the buying client can't read it back directly. Only for
/// test assertions; real code must keep using
/// `ProductRepository.watchStockMovements`.
Future<List<Map<String, dynamic>>> fetchStockMovementsAsAdmin(
  String productId,
) async {
  final rows = await _adminClient.rpc(
    'test_fetch_stock_movements',
    params: {'p_product_id': productId},
  );
  return (rows as List).cast<Map<String, dynamic>>();
}
