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
  await _withDeadlockRetry(() => _adminClient.rpc('test_reset_and_seed'));
  // Les comptes livreurs sont seedés à part (`0047_test_seed_couriers.sql`),
  // pour ne pas recopier les six cents lignes de `test_reset_and_seed()` dans
  // une migration juste pour y ajouter deux comptes.
  await _adminClient.rpc('test_seed_couriers');
  // Adresses de retrait : la garde de `0050` refuse de confier une commande
  // à la livraison MTC sans elles, donc le décor doit les poser.
  await _adminClient.rpc('test_seed_supplier_pickup_points');
}

/// Rejoue [action] si Postgres détecte un interblocage (40P01).
///
/// `test_reset_and_seed()` et la RPC des variantes désactivent toutes deux un
/// trigger sur `products` le temps de leur transaction, ce qui demande un
/// verrou **exclusif** sur la table. Une connexion de longue durée — PostgREST,
/// Realtime — qui lit `products` puis `suppliers` au même instant ferme le
/// cycle, et Postgres annule l'une des deux. `dart_test.yaml` sérialise déjà
/// les fichiers de test pour cette raison, mais ça ne couvre pas les sessions
/// qui ne sont pas des tests.
///
/// Un interblocage est transitoire par définition : la victime est annulée,
/// l'autre passe. Rejouer est donc la réponse correcte, et non masquer un
/// défaut — le même code réussit immédiatement au coup suivant.
Future<void> _withDeadlockRetry(
  Future<void> Function() action, {
  int attempts = 3,
}) async {
  for (var i = 1; ; i++) {
    try {
      await action();
      return;
    } on PostgrestException catch (e) {
      if (e.code != '40P01' || i >= attempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 150 * i));
    }
  }
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

/// Force le statut d'un groupe fournisseur via `test_set_group_status`
/// (`0047_test_seed_couriers.sql`) — pour remonter un décor que le jeu de
/// démo livre déjà joué, pas pour remplacer une vraie transition de statut.
Future<void> adminSetGroupStatus({
  required String groupId,
  required String status,
}) async {
  await _adminClient.rpc(
    'test_set_group_status',
    params: {'p_group_id': groupId, 'p_status': status},
  );
}

/// Statut courant d'un groupe fournisseur, lu sans session.
Future<String> adminFetchGroupStatus(String groupId) async {
  final status = await _adminClient.rpc(
    'test_fetch_group_status',
    params: {'p_group_id': groupId},
  );
  return status as String;
}

/// Bascule le mode de livraison d'un groupe — pour qu'un test portant sur les
/// transitions du fournisseur travaille bien sur une commande qu'il livre
/// lui-même.
Future<void> adminSetGroupDeliveryMode({
  required String groupId,
  required String mode,
}) async {
  await _adminClient.rpc(
    'test_set_group_delivery_mode',
    params: {'p_group_id': groupId, 'p_mode': mode},
  );
}

/// Statut d'un livreur, lu sans session — la fiche n'est visible que de lui
/// et du staff.
Future<String> adminFetchCourierStatus(String courierId) async {
  final status = await _adminClient.rpc(
    'test_fetch_courier_status',
    params: {'p_courier_id': courierId},
  );
  return status as String;
}

/// Efface l'adresse de retrait d'un fournisseur, pour vérifier que la
/// livraison MTC la réclame bien (`0050`).
Future<void> adminClearSupplierPickupPoint({required String supplierId}) async {
  await _adminClient.rpc(
    'test_clear_supplier_pickup_point',
    params: {'p_supplier_id': supplierId},
  );
}

/// Gives a product a single "Standard" default variant, bypassing RLS and
/// the full characteristics/options flow via `test_give_product_a_variant()`
/// (`0022_test_variant_helper.sql`) — for staging "this product is
/// variant-backed" in a test that isn't itself about composing
/// characteristics (e.g. activating a draft product, low-stock
/// notifications), now that `products_active_requires_variants`
/// (`0021_backfill_default_variants_and_require_variant.sql`) requires it
/// before a product can go `active`. Defaults to the product's own current
/// price/stock when not given — same numbers the real
/// `product_variants_aggregate_products` trigger would then recompute back
/// onto the product, so callers that don't care about the exact figures can
/// omit them without the product's price/stock silently changing.
Future<void> giveProductADefaultVariantAsAdmin(
  String productId, {
  int? priceFcfa,
  int? stockQuantity,
}) async {
  await _adminClient.rpc(
    'test_give_product_a_variant',
    params: {
      'p_product_id': productId,
      'p_price_fcfa': priceFcfa,
      'p_stock_quantity': stockQuantity,
    },
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

/// Reads a user's notifications, bypassing RLS via
/// `test_fetch_notifications_for_user()` (`0007_test_notification_helper.sql`)
/// — a notification's recipient is often not the session that just
/// triggered it (e.g. a client's checkout notifies each supplier), and
/// tests asserting "X got notified" shouldn't need to log in as X purely
/// to read the result back. Not a substitute for
/// `NotificationRepository.watchForUser`, which real code and most tests
/// should keep going through.
Future<List<Map<String, dynamic>>> fetchNotificationsForUserAsAdmin(
  String userId,
) async {
  final rows = await _adminClient.rpc(
    'test_fetch_notifications_for_user',
    params: {'p_user_id': userId},
  );
  return (rows as List).cast<Map<String, dynamic>>();
}

/// Reads a user's registered device tokens, bypassing RLS via
/// `test_fetch_device_tokens_for_user()` (`0035_test_device_token_helper.sql`)
/// — same rationale as [fetchNotificationsForUserAsAdmin]. Not a substitute
/// for `DeviceTokenRepository`, which real code should keep going through.
Future<List<Map<String, dynamic>>> fetchDeviceTokensForUserAsAdmin(
  String userId,
) async {
  final rows = await _adminClient.rpc(
    'test_fetch_device_tokens_for_user',
    params: {'p_user_id': userId},
  );
  return (rows as List).cast<Map<String, dynamic>>();
}

/// Calls the production `get_device_tokens_for_notification_user()` RPC
/// directly with the admin client — this *is* the fan-out the push Edge
/// Function relies on, `security definer`/`service_role`-only by design
/// (see `0034_device_tokens.sql`), so there's no non-admin way to exercise
/// it from a test.
Future<List<String>> tokensForNotificationUserAsAdmin(String userId) async {
  final rows = await _adminClient.rpc(
    'get_device_tokens_for_notification_user',
    params: {'p_user_id': userId},
  );
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map((r) => r['fcm_token'] as String)
      .toList();
}

/// Reads whether `deleted_at` is set on a user's `profiles`/`suppliers` rows,
/// bypassing RLS via `test_fetch_account_deletion_state()`
/// (`0037_test_account_deactivation_helper.sql`) — a deleted account's own
/// `suppliers` row is invisible through the normal public-select policy by
/// design, which is exactly what a test needs to confirm.
Future<({DateTime? profileDeletedAt, DateTime? supplierDeletedAt})>
fetchAccountDeletionStateAsAdmin(String userId) async {
  final row = await _adminClient
      .rpc('test_fetch_account_deletion_state', params: {'p_user_id': userId})
      .single();
  DateTime? parse(String? value) => value == null ? null : DateTime.parse(value);
  return (
    profileDeletedAt: parse(row['profile_deleted_at'] as String?),
    supplierDeletedAt: parse(row['supplier_deleted_at'] as String?),
  );
}
