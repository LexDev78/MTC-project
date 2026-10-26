import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'dart:typed_data';

import 'dart:io';

import 'dart:convert';

import 'package:http/http.dart' as http;
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
///
/// `--dart-define=MTC_TEST_SUPABASE_URL=…` lance la suite contre une autre
/// pile locale — une pile de vérification montée à part, pour ne pas vider
/// celle où l'on essaie l'app à la main. Les clés restent celles-ci : elles
/// découlent du `JWT_SECRET` local par défaut, le même sur toute pile.
const _supabaseUrl = String.fromEnvironment(
  'MTC_TEST_SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

/// Le User-Agent de toutes les sessions ouvertes par les tests. GoTrue
/// l'inscrit dans `auth.sessions.user_agent` : c'est ainsi que
/// [resetAndSeed] reconnaît ses propres sessions, et distingue celles d'une
/// personne qui se sert de l'app sur la même base.
const _testUserAgent = 'mtc-tests';

/// `--dart-define=MTC_FORCE_RESET=true` : réinitialiser même quand l'app est
/// ouverte sur la base — en sachant ce qu'on efface.
const _forceReset = bool.fromEnvironment('MTC_FORCE_RESET');

/// A fresh, session-less client — one per test, exactly what
/// `supabaseClientProvider` is overridden with in every `integration`-tagged
/// test. Plain `package:supabase` (not `supabase_flutter`) since tests don't
/// need `Supabase.initialize()`'s Flutter-specific local-storage session
/// persistence — each test starts signed out and logs in itself.
///
/// Ses sessions portent le User-Agent [_testUserAgent] : voir [resetAndSeed].
SupabaseClient createTestSupabaseClient() {
  _allowRealHttpRequests();
  return SupabaseClient(
    _supabaseUrl,
    _anonKey,
    headers: const {'User-Agent': _testUserAgent},
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
///
/// Refuse de tourner tant que l'app est ouverte sur cette base (voir
/// [_refuseResetWhileAppInUse]).
Future<void> resetAndSeed() async {
  _allowRealHttpRequests();
  await _refuseResetWhileAppInUse();
  // Avec un vrai service d'envoi branché en local (`0125`), les codes
  // demandés par les tests partiraient pour de vrai : la base refuse
  // (`0126`).
  await _adminClient.rpc('test_assert_mail_sandbox');
  await _withTransientRetry(() => _adminClient.rpc('test_reset_and_seed'));
  // Les comptes livreurs sont seedés à part (`0047_test_seed_couriers.sql`),
  // pour ne pas recopier les six cents lignes de `test_reset_and_seed()` dans
  // une migration juste pour y ajouter deux comptes.
  await _adminClient.rpc('test_seed_couriers');
  // Adresses de retrait : la garde de `0050` refuse de confier une commande
  // à la livraison MTC sans elles, donc le décor doit les poser.
  await _adminClient.rpc('test_seed_supplier_pickup_points');
  // La file de purge et le registre des modèles ne pendent à aucun compte :
  // le `truncate … cascade` du décor ne les atteint pas (`0088`).
  await _adminClient.rpc('test_reset_ai_scratch');
}

/// Arrête les tests avant qu'ils n'effacent une base dont quelqu'un se sert.
///
/// La réinitialisation vide `auth.users` et remet chaque compte du décor à
/// `password123`. Lancée pendant qu'on essaie l'app à la main sur la même
/// base, elle défait ce qu'on vient d'y faire, en silence. Le 18/10/2026,
/// des changements de mot de passe faits depuis Chrome ont ainsi été annulés
/// une à deux secondes après avoir réussi (`0111_test_live_app_sessions.sql`
/// détaille le constat).
///
/// Une session récente qui ne vient pas des tests — Chrome, ou l'app sur un
/// téléphone — arrête donc la réinitialisation, avec de quoi savoir qui et
/// quoi faire.
Future<void> _refuseResetWhileAppInUse() async {
  if (_forceReset) return;
  final sessions =
      await _adminClient.rpc(
            'test_live_app_sessions',
            params: {'p_test_user_agent': _testUserAgent},
          )
          as List<dynamic>;
  if (sessions.isEmpty) return;

  final session = sessions.first as Map<String, dynamic>;
  final userAgent = session['user_agent'] as String? ?? '';
  final ouVient = userAgent.contains('Mozilla')
      ? 'un navigateur'
      : userAgent.startsWith('Dart/')
      ? 'l\'app sur un appareil'
      : 'un client inconnu';
  final minutes = DateTime.now()
      .difference(DateTime.parse(session['last_seen'] as String))
      .inMinutes;
  throw StateError(
    'Réinitialisation refusée : l\'app est ouverte sur cette base locale — '
    '${session['email']}, depuis $ouVient, actif il y a $minutes min.\n'
    'Les tests effacent tous les comptes et remettent chaque mot de passe à '
    'password123 : ce qui vient d\'y être fait serait perdu.\n'
    'Déconnectez-vous de l\'app (une app fermée sans déconnexion cesse de '
    'compter après 70 min), ou relancez avec '
    '--dart-define=MTC_FORCE_RESET=true.',
  );
}

/// Rejoue [action] si Postgres détecte un interblocage (40P01), ou si
/// l'attente d'un verrou dépasse la limite de 8 s du rôle `authenticator`
/// (57014).
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
///
/// L'attente de verrou l'est aussi. Mesuré le 18/10/2026 : le `truncate`
/// de la réinitialisation, qui demande un verrou exclusif sur `auth.users`
/// et toutes les tables qui en dépendent, a attendu derrière une lecture du
/// journal par Realtime (`realtime.list_changes`, 12 s — la seule requête
/// longue que le journal de Postgres montre à cet instant) et a été annulé
/// à 8 s. Au coup suivant, la lecture est finie.
Future<void> _withTransientRetry(
  Future<void> Function() action, {
  int attempts = 3,
}) async {
  for (var i = 1; ; i++) {
    try {
      await action();
      return;
    } on PostgrestException catch (e) {
      final transitoire = e.code == '40P01' || e.code == '57014';
      if (!transitoire || i >= attempts) rethrow;
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

/// Remet le dossier d'un livreur à l'état d'un nouvel inscrit : aucune
/// pièce, aucun dépôt (`test_reset_courier_dossier`, `0105`).
///
/// Un dossier déposé est gelé par la politique d'écriture — c'est tout son
/// intérêt —, donc le livreur ne peut pas le défaire lui-même, et un test qui
/// veut partir d'un dossier vierge a besoin du rôle de service.
Future<void> adminResetCourierDossier({required String courierId}) async {
  await _adminClient.rpc(
    'test_reset_courier_dossier',
    params: {'p_courier_id': courierId},
  );
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
/// Pose une notification sans passer par une session cliente.
///
/// Depuis `0064`, une session cliente n'a plus le droit d'en insérer : elles
/// sont produites par l'événement qui les justifie. Les tests qui vérifient
/// l'**affichage** et le marquage comme lu ont pourtant besoin d'en créer,
/// d'où cette RPC réservée à `service_role`.
/// Déclare un modèle dans le registre (`0085`).
///
/// Nécessaire avant d'écrire une empreinte : `product_embeddings.model`
/// référence `ai_models`, et la clé étrangère est là pour qu'une faute de
/// frappe ne crée pas un troisième espace vectoriel que personne ne
/// remarquerait.
Future<void> registerAiModelAsAdmin({
  required String name,
  int dim = 1024,
  String provider = 'self_hosted',
  String role = 'candidate',
}) async {
  await _adminClient.from('ai_models').upsert({
    'name': name,
    'kind': 'embedding',
    'dim': dim,
    'provider': provider,
    'role': role,
  });
}

/// Écrit l'empreinte d'un produit, comme le ferait la fonction edge
/// d'indexation.
///
/// Les tests de recherche par photo n'appellent aucun modèle : ce qui se
/// vérifie ici, c'est le **rapprochement** — l'ordre des résultats, le
/// seuil, et les produits qui n'ont rien à y faire. Le vecteur peut donc
/// être fabriqué, à condition d'avoir la dimension déclarée par le modèle.
///
/// Le modèle est déclaré au passage s'il ne l'est pas déjà : laisser chaque
/// test y penser produirait surtout des échecs de clé étrangère sans rapport
/// avec ce qu'il vérifie.
Future<void> upsertEmbeddingAsAdmin({
  required String productId,
  required List<double> embedding,
  String model = 'test-model',
  String sourceImageUrl = 'test://image',
}) async {
  await registerAiModelAsAdmin(name: model, dim: embedding.length);
  await _adminClient.rpc(
    'upsert_product_embedding',
    params: {
      'p_product_id': productId,
      'p_embedding': embedding,
      'p_model': model,
      'p_source_image_url': sourceImageUrl,
    },
  );
}

/// L'écriture d'une empreinte **sans** déclarer le modèle au passage.
///
/// Pour les tests qui vérifient ce que la base refuse : un modèle absent du
/// registre, une dimension inattendue. `upsertEmbeddingAsAdmin` déclare le
/// modèle lui-même, ce qui masquerait justement le refus attendu.
Future<void> upsertEmbeddingRawAsAdmin({
  required String productId,
  required List<double> embedding,
  required String model,
  String sourceImageUrl = 'test://image',
}) async {
  await _adminClient.rpc(
    'upsert_product_embedding',
    params: {
      'p_product_id': productId,
      'p_embedding': embedding,
      'p_model': model,
      'p_source_image_url': sourceImageUrl,
    },
  );
}

/// Les produits qu'il reste à indexer, comme la fonction edge les demande.
///
/// `model` compte : un catalogue entièrement indexé pour un modèle est
/// entièrement à indexer pour le suivant (`0085`).
Future<List<({String productId, String name, String? imageUrl})>>
fetchProductsNeedingEmbeddingAsAdmin({
  int limit = 200,
  String? model = 'test-model',
}) async {
  final rows = await _adminClient.rpc(
    'products_needing_embedding',
    params: {'p_limit': limit, 'p_model': model},
  );
  return [
    for (final row in (rows as List).cast<Map<String, dynamic>>())
      (
        productId: row['product_id'] as String,
        name: row['name'] as String,
        imageUrl: row['image_url'] as String?,
      ),
  ];
}

/// Rapproche un vecteur du catalogue, comme la fonction edge le fait après
/// avoir calculé l'empreinte d'une photo.
Future<List<({String productId, double similarity})>> searchByEmbeddingAsAdmin({
  required List<double> embedding,

  /// Le modèle par défaut est celui du harnais, pas celui en service : les
  /// tests fabriquent leurs vecteurs, ils ne passent pas par Voyage.
  /// Passer `null` explicitement retombe sur le modèle servant, comme la
  /// fonction edge.
  String? model = 'test-model',
  int limit = 24,
  double minSimilarity = 0.25,
}) async {
  final rows = await _adminClient.rpc(
    'search_products_by_embedding',
    params: {
      'p_embedding': embedding,
      'p_model': model,
      'p_limit': limit,
      'p_min_similarity': minSimilarity,
    },
  );
  return [
    for (final row in (rows as List).cast<Map<String, dynamic>>())
      (
        productId: row['product_id'] as String,
        similarity: (row['similarity'] as num).toDouble(),
      ),
  ];
}

/// Conserve une recherche par photo, comme la fonction edge le fait après
/// avoir répondu (`0086`).
Future<String> recordVisualSearchQueryAsAdmin({
  required String userId,
  required String imagePath,
  required List<({String productId, double similarity})> candidates,
  String model = 'test-model',
  List<double>? embedding,
}) async {
  await registerAiModelAsAdmin(name: model, dim: embedding?.length ?? 1024);
  final id = await _adminClient.rpc(
    'record_visual_search_query',
    params: {
      'p_user_id': userId,
      'p_image_path': imagePath,
      'p_model': model,
      'p_embedding': embedding,
      'p_candidates': [
        for (final candidate in candidates)
          {
            'product_id': candidate.productId,
            'similarity': candidate.similarity,
          },
      ],
    },
  );
  return id as String;
}

/// Les étiquettes enregistrées pour une recherche.
Future<List<String>> fetchVisualSearchClicksAsAdmin(String queryId) async {
  final rows = await _adminClient
      .from('visual_search_clicks')
      .select('product_id')
      .eq('query_id', queryId);
  return [
    for (final row in (rows as List).cast<Map<String, dynamic>>())
      row['product_id'] as String,
  ];
}

/// Les fichiers que la base a demandé de supprimer (`0088`).
///
/// Le SQL ne peut pas effacer un fichier — Supabase le refuse — donc il
/// enregistre l'intention et `ml/purge_queries.py` l'exécute.
Future<List<String>> fetchStoragePurgeQueueAsAdmin({
  String bucket = 'visual-search-queries',
}) async {
  final rows = await _adminClient
      .from('storage_purge_queue')
      .select('object_path')
      .eq('bucket_id', bucket);
  return [
    for (final row in (rows as List).cast<Map<String, dynamic>>())
      row['object_path'] as String,
  ];
}

/// Promeut les recherches étiquetées au rang d'étalon (`0087`).
Future<int> promoteQueriesToEvalAsAdmin({int limit = 50}) async {
  final count = await _adminClient.rpc(
    'promote_queries_to_eval',
    params: {'p_limit': limit},
  );
  return count as int;
}

/// Le jeu d'entraînement tel que `ml/export_dataset.py` le lit.
Future<List<Map<String, dynamic>>> exportTrainingPairsAsAdmin({
  int limit = 500,
}) async {
  final rows = await _adminClient.rpc(
    'export_training_pairs',
    params: {'p_since': null, 'p_limit': limit},
  );
  return (rows as List).cast<Map<String, dynamic>>();
}

/// Écrit l'empreinte d'une photo d'évaluation pour un modèle.
Future<void> upsertEvalEmbeddingAsAdmin({
  required String exampleId,
  required String model,
  required List<double> embedding,
}) async {
  await _adminClient.from('ai_eval_embeddings').upsert({
    'example_id': exampleId,
    'model': model,
    'embedding': '[${embedding.join(',')}]',
    'dim': embedding.length,
  });
}

/// Les photos de l'étalon.
Future<List<({String id, String imagePath, String expectedProductId})>>
fetchEvalExamplesAsAdmin() async {
  final rows = await _adminClient
      .from('ai_eval_examples')
      .select('id, image_path, expected_product_id');
  return [
    for (final row in (rows as List).cast<Map<String, dynamic>>())
      (
        id: row['id'] as String,
        imagePath: row['image_path'] as String,
        expectedProductId: row['expected_product_id'] as String,
      ),
  ];
}

/// La note d'un modèle sur l'étalon (`0087`).
Future<({int examples, int found, double? recall, double? mrr})>
evaluateModelRecallAsAdmin({required String model, int k = 5}) async {
  final rows = await _adminClient.rpc(
    'evaluate_model_recall',
    params: {'p_model': model, 'p_k': k},
  );
  final row = (rows as List).cast<Map<String, dynamic>>().single;
  return (
    examples: row['examples'] as int,
    found: row['found'] as int,
    recall: (row['recall_at_k'] as num?)?.toDouble(),
    mrr: (row['mrr'] as num?)?.toDouble(),
  );
}

/// Pose une course déjà livrée sur un groupe fournisseur.
///
/// Évite d'ouvrir quatre sessions sur l'appareil pour lire et scanner deux
/// codes QR : les parcours visuels qui s'intéressent à l'après-livraison
/// partent de là. Le chemin réel reste couvert par `delivery_codes_test`.
Future<String> seedDeliveredDeliveryAsAdmin({
  required String groupId,
  required String courierId,
}) async {
  final id = await _adminClient.rpc(
    'test_seed_delivered_delivery',
    params: {'p_group_id': groupId, 'p_courier_id': courierId},
  );
  return id as String;
}

/// Dépose un fichier dans un bucket Storage sans session utilisateur.
///
/// Les parcours visuels ont besoin de **vraies** images pour montrer ce
/// qu'un acheteur voit : un chemin qui ne pointe sur rien ne rend qu'une
/// icône d'image cassée, ce qui ne dit rien de la mise en page. Le
/// sélecteur de photos, lui, n'est pas pilotable depuis un test (c'est une
/// feuille native), d'où ce dépôt direct.
Future<void> uploadToBucketAsAdmin({
  required String bucket,
  required String path,
  required Uint8List bytes,
  String contentType = 'image/jpeg',
}) async {
  await _adminClient.storage
      .from(bucket)
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
}

Future<void> insertNotificationAsAdmin({
  required String userId,
  required String type,
  required String title,
  required String body,
  String? referenceId,
}) async {
  await _adminClient.rpc(
    'test_insert_notification',
    params: {
      'p_user_id': userId,
      'p_type': type,
      'p_title': title,
      'p_body': body,
      'p_reference_id': referenceId,
    },
  );
}

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
  DateTime? parse(String? value) =>
      value == null ? null : DateTime.parse(value);
  return (
    profileDeletedAt: parse(row['profile_deleted_at'] as String?),
    supplierDeletedAt: parse(row['supplier_deleted_at'] as String?),
  );
}

/// Crée le compte d'un collaborateur rattaché à une boutique (`0093`).
///
/// Fait ce que la fonction edge `create-collaborator` fait en production :
/// un compte créé avec la clé de service, dont `app_metadata` porte le
/// rattachement (`0128` — `user_metadata` s'écrit par n'importe qui à
/// l'inscription, il ne rattache plus personne). Le passer par la fonction
/// edge demanderait de la servir pendant les tests, pour vérifier une
/// mécanique qui est tout entière dans `apply_account_provisioning`.
Future<String> createCollaboratorAsAdmin({
  required String supplierId,
  required String username,
  required Set<String> permissions,
  String displayName = 'Collaborateur de test',
}) async {
  final response = await _adminClient.auth.admin.createUser(
    AdminUserAttributes(
      email: pseudoEmail(username),
      password: 'password123',
      emailConfirm: true,
      userMetadata: {
        'display_name': displayName,
        'username_or_phone': username,
        'phone_number': '+22370000111',
      },
      appMetadata: {
        'collaborator_of': supplierId,
        'permissions': permissions.toList(),
        'invited_by': supplierId,
      },
    ),
  );
  return response.user!.id;
}

/// Efface le rattachement d'un collaborateur comme le faisait le retrait
/// **avant** `0110` — pour reproduire les comptes retirés à cette époque,
/// qui n'ont plus ni boutique à eux ni ligne de rattachement. Le rôle de
/// service passe outre la RLS ; une session ordinaire ne le pourrait pas.
Future<void> adminDeleteCollaboratorLink(String userId) async {
  await _adminClient
      .from('supplier_collaborators')
      .delete()
      .eq('user_id', userId);
}

/// La boîte de test de la pile locale (Mailpit), où la base envoie ses
/// e-mails (`send_mail`, `0124`).
/// L'adresse de la pile visée, pour un test qui monte son propre client.
const testSupabaseUrl = _supabaseUrl;

const _mailpitUrl = String.fromEnvironment(
  'MTC_TEST_MAILPIT_URL',
  defaultValue: 'http://127.0.0.1:54324',
);

/// Le code à six chiffres du dernier e-mail reçu par [adresse] — lu là où
/// l'utilisateur le lirait, dans sa boîte.
///
/// La base n'envoie qu'après sa transaction (`pg_net`) : on attend que
/// l'e-mail arrive. Les e-mails lus sont effacés, pour que le test suivant
/// parte d'une boîte où le seul code pour cette adresse est le sien.
Future<String> codeRecuPar(
  String adresse, {
  Duration delai = const Duration(seconds: 10),
}) async {
  _allowRealHttpRequests();
  final client = http.Client();
  try {
    final fin = DateTime.now().add(delai);
    while (DateTime.now().isBefore(fin)) {
      final reponse = await client.get(
        Uri.parse('$_mailpitUrl/api/v1/messages?limit=100'),
      );
      final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
      final messages = [
        for (final m in (corps['messages'] as List? ?? const []))
          if (m case final Map<String, dynamic> message
              when (message['To'] as List).any(
                (d) =>
                    d is Map<String, dynamic> &&
                    (d['Address'] as String).toLowerCase() ==
                        adresse.toLowerCase(),
              ))
            message,
      ];
      if (messages.isNotEmpty) {
        // Mailpit range du plus récent au plus ancien.
        final sujet = messages.first['Subject'] as String;
        final code = RegExp(r'([0-9]{6})$').firstMatch(sujet)?.group(1);
        await client.delete(
          Uri.parse('$_mailpitUrl/api/v1/messages'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'IDs': [for (final m in messages) m['ID']],
          }),
        );
        if (code == null) {
          throw StateError('E-mail sans code pour $adresse : « $sujet »');
        }
        return code;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Aucun code reçu par $adresse dans Mailpit.');
  } finally {
    client.close();
  }
}

/// Efface de Mailpit tous les e-mails reçus par [adresse] — ceux qui ne
/// portent pas de code (une alerte), pour laisser la boîte propre.
Future<void> viderBoitePour(String adresse) async {
  _allowRealHttpRequests();
  final client = http.Client();
  try {
    // L'envoi part après la transaction : laisser le temps d'arriver.
    await Future<void>.delayed(const Duration(seconds: 1));
    final reponse = await client.get(
      Uri.parse('$_mailpitUrl/api/v1/messages?limit=100'),
    );
    final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
    final ids = [
      for (final m in (corps['messages'] as List? ?? const []))
        if (m case final Map<String, dynamic> message
            when (message['To'] as List).any(
              (d) =>
                  d is Map<String, dynamic> &&
                  (d['Address'] as String).toLowerCase() ==
                      adresse.toLowerCase(),
            ))
          message['ID'],
    ];
    if (ids.isEmpty) return;
    await client.delete(
      Uri.parse('$_mailpitUrl/api/v1/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'IDs': ids}),
    );
  } finally {
    client.close();
  }
}
