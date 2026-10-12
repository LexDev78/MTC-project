@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/ratings/data/datasources/supabase_review_datasource.dart';
import 'package:mtc_app/features/ratings/data/repositories/supabase_review_repository.dart';
import 'package:mtc_app/features/ratings/domain/repositories/review_repository.dart';

import '../../support/supabase_test_harness.dart';

// Avis sur la fiche produit : médias et commentaires (`0061`).
//
// Deux choses s'y jouent, et ce sont elles qui sont testées ici :
//
//  * la **visibilité** — un visiteur sans compte doit lire les avis d'un
//    produit, alors que le rattachement passe par `order_items`, qu'il n'a
//    pas le droit de lire ;
//  * l'**authenticité** — le nom affiché et l'auteur d'un commentaire sont
//    posés par la base. Sur une page publique, pouvoir signer du nom d'un
//    autre, ou se faire passer pour le vendeur, serait le défaut le plus
//    coûteux de la fonctionnalité.
Future<SupabaseClient> _signIn(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return client;
}

void main() {
  // « Tissu Bogolan traditionnel », vendu par Bogolan Bamako (fournisseur1).
  const productId = 'b0fe527e-1f73-55e6-b24e-4d985576d473';
  // L'avis du jeu de démo sur ce produit : il est de client2, Moussa Diarra.
  const reviewId = 'c3d4d48f-f9a9-59b5-8798-4a9964995afa';
  const client1Id = '04060d99-e34d-520e-8b75-631ff4d3c10c'; // Awa Traoré
  const client2Id = '3355adef-385d-5eee-a565-815c8cf8e4d3'; // Moussa Diarra
  // Deuxième commande livrée d'Awa Traoré, portant le même produit et
  // encore sans avis : de quoi en déposer un avec des photos.
  const unreviewedGroupId = 'efbd44fe-a725-533d-ba6c-a9c867b161cb';
  const supplier1Id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3';

  setUp(resetAndSeed);

  test(
    'un visiteur sans compte lit les avis d\'un produit, sans pour autant '
    'accéder aux commandes qui les rattachent',
    () async {
      // Session anonyme : c'est le cas d'usage central (lire les avis avant
      // de créer un compte), et celui que le rattachement par `order_items`
      // interdirait sans une RPC `security definer`.
      final anonClient = createTestSupabaseClient();
      final ReviewRepository asVisitor = SupabaseReviewRepository(
        SupabaseReviewDatasource(anonClient),
      );

      final reviews = await asVisitor.fetchProductReviews(
        productId: productId,
      );
      expect(reviews, hasLength(1));
      expect(reviews.single.stars, 5);
      expect(reviews.single.authorName, 'Moussa Diarra');
      expect(reviews.single.comments, isEmpty);

      final summary = await asVisitor.fetchProductReviewSummary(productId);
      expect(summary.reviewCount, 1);
      expect(summary.ratingAverage, 5.0);

      // La RPC ouvre les avis, pas les commandes : la table reste fermée.
      await expectLater(
        anonClient.from('order_items').select(),
        throwsA(isA<PostgrestException>()),
      );

      await anonClient.dispose();
    },
  );

  test(
    'un client commente l\'avis d\'un autre, et ne peut ni le signer du nom '
    'de quelqu\'un d\'autre ni se faire passer pour le vendeur',
    () async {
      final clientClient = await _signIn('client1'); // Awa Traoré
      final asClient = SupabaseReviewRepository(
        SupabaseReviewDatasource(clientClient),
      );

      await asClient.addComment(
        reviewId: reviewId,
        body: 'Le tissu est-il épais ?',
      );

      // Tentative d'usurpation : écriture directe dans la table en se
      // donnant un autre auteur, un autre nom, et le drapeau « vendeur ».
      // Le trigger repose les trois.
      await clientClient.from('review_comments').insert({
        'review_id': reviewId,
        'body': 'Réponse du vendeur : produit parfait.',
        'author_id': client2Id,
        'author_display_name_snapshot': 'Bogolan Bamako',
        'author_is_supplier': true,
      });

      final anonClient = createTestSupabaseClient();
      final reviews = await SupabaseReviewRepository(
        SupabaseReviewDatasource(anonClient),
      ).fetchProductReviews(productId: productId);
      final comments = reviews.single.comments;

      expect(comments, hasLength(2));
      expect(
        comments.map((c) => c.authorName).toSet(),
        {'Awa Traoré'},
        reason: 'le nom est pris dans `profiles`, pas dans la requête',
      );
      expect(
        comments.every((c) => !c.authorIsSupplier),
        isTrue,
        reason: 'le drapeau vendeur est calculé, pas déclaré',
      );

      await anonClient.dispose();
      await clientClient.dispose();
    },
  );

  test('le commentaire du vendeur est signalé comme tel', () async {
    // Bogolan Bamako est bien le fournisseur noté par cet avis.
    final supplierClient = await _signIn('fournisseur1');
    await SupabaseReviewRepository(
      SupabaseReviewDatasource(supplierClient),
    ).addComment(reviewId: reviewId, body: 'Merci ! Tissu 100% coton.');

    final anonClient = createTestSupabaseClient();
    final reviews = await SupabaseReviewRepository(
      SupabaseReviewDatasource(anonClient),
    ).fetchProductReviews(productId: productId);

    // Ce drapeau est ce qui distingue visuellement une réponse du vendeur
    // d'un avis de client sur une page publique.
    expect(reviews.single.comments.single.authorIsSupplier, isTrue);

    await anonClient.dispose();
    await supplierClient.dispose();
  });

  test(
    'un média rangé dans le dossier d\'un autre compte est refusé',
    () async {
      final clientClient = await _signIn('client1');

      // Le chemin désigne le dossier de client2. Storage refuserait l'envoi ;
      // ce test vérifie que la **ligne** est refusée aussi, sans quoi on
      // publierait un commentaire affichant le fichier d'un autre.
      await expectLater(
        clientClient.from('review_comments').insert({
          'review_id': reviewId,
          'body': 'Photo empruntée.',
          'image_paths': ['$client2Id/photo.jpg'],
        }),
        throwsA(isA<PostgrestException>()),
      );

      await clientClient.dispose();
    },
  );

  test('le nombre de photos d\'un commentaire est plafonné', () async {
    final clientClient = await _signIn('client1');

    await expectLater(
      clientClient.from('review_comments').insert({
        'review_id': reviewId,
        'body': 'Galerie entière.',
        'image_paths': [for (var i = 0; i < 5; i++) '$client1Id/photo$i.jpg'],
      }),
      throwsA(isA<PostgrestException>()),
      reason: 'sans plafond, un seul commentaire occupe la fiche',
    );

    // Quatre passent : la limite est bien à 4, pas en dessous.
    await clientClient.from('review_comments').insert({
      'review_id': reviewId,
      'body': 'Quatre photos.',
      'image_paths': [for (var i = 0; i < 4; i++) '$client1Id/photo$i.jpg'],
    });

    await clientClient.dispose();
  });

  test(
    'un avis déposé avec des photos les porte sur la fiche, et seuls les '
    'produits réellement achetés en héritent',
    () async {
      final clientClient = await _signIn('client1');
      final asClient = SupabaseReviewRepository(
        SupabaseReviewDatasource(clientClient),
      );
      final orderRow = await clientClient
          .from('order_supplier_groups')
          .select('order_id')
          .eq('id', unreviewedGroupId)
          .single();

      // Les médias accompagnent l'avis dès son dépôt : `reviews` n'ouvre
      // aucune mise à jour au client (seul le vendeur répond), donc une
      // photo ajoutée après coup n'existe pas.
      await asClient.submitReview(
        orderId: orderRow['order_id'] as String,
        supplierGroupId: unreviewedGroupId,
        clientId: client1Id,
        supplierId: supplier1Id,
        stars: 4,
        comment: 'Conforme, voici le tissu reçu.',
        imagePaths: ['$client1Id/recu.jpg'],
      );

      final anonClient = createTestSupabaseClient();
      final asVisitor = SupabaseReviewRepository(
        SupabaseReviewDatasource(anonClient),
      );
      final reviews = await asVisitor.fetchProductReviews(
        productId: productId,
      );
      expect(reviews, hasLength(2));

      final withPhoto = reviews.firstWhere((r) => r.imagePaths.isNotEmpty);
      expect(withPhoto.imagePaths, ['$client1Id/recu.jpg']);
      expect(withPhoto.authorName, 'Awa Traoré');

      // La moyenne de la fiche suit : 5 et 4.
      final summary = await asVisitor.fetchProductReviewSummary(productId);
      expect(summary.reviewCount, 2);
      expect(summary.ratingAverage, 4.5);

      // Un autre produit n'hérite pas de cet avis : le rattachement passe
      // par les lignes de la commande, pas par le fournisseur.
      final otherProduct = await asVisitor.fetchProductReviews(
        productId: 'd9d25e13-71ac-51c4-93f7-ed042a996500',
      );
      expect(otherProduct.map((r) => r.id), isNot(contains(reviewId)));

      await anonClient.dispose();
      await clientClient.dispose();
    },
  );
}
