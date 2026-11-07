import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/comments/domain/entities/product_comment.dart';
import 'package:mtc_app/features/comments/domain/repositories/product_comment_repository.dart';
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/comments/presentation/widgets/product_comments_modal.dart';

import '../../support/shop_fixtures.dart';

// Un commentaire refusé par la base — trop de commentaires d'affilée
// (`0153`), produit retiré de la vente — le dit. Le champ est déjà vidé à
// l'envoi : sans message, le commentaire disparaissait sans un mot.
const _refus = 'Vous envoyez trop de commentaires à la suite : patientez une minute.';

class _Commentaires implements ProductCommentRepository {
  _Commentaires({this.refus});

  final PostgrestException? refus;
  final envois = <String>[];

  @override
  Stream<List<ProductComment>> watchForProduct(String productId) => Stream.value(const []);

  @override
  Future<void> addComment({
    required String productId,
    required String supplierId,
    required String authorId,
    required String authorName,
    required bool isSupplier,
    required String text,
    String? parentId,
    CommentAttachmentType attachmentType = CommentAttachmentType.none,
    String? attachmentPath,
    int? voiceDurationSeconds,
  }) async {
    if (refus != null) throw refus!;
    envois.add(text);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalogue implements ProductRepository {
  @override
  Future<Product> getById(String id) async => produit(
    id: id,
    nom: 'Boubou en bogolan brodé',
    boutique: 'Bogolan Bamako',
    photo: 'assets/images/products/textiles/fabric.jpg',
    categorie: ProductCategory.textilesBogolan,
    prix: 45000,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _ouvrir(WidgetTester tester, _Commentaires depot) async {
  tester.view.physicalSize = const Size(375, 800) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
        productCommentRepositoryProvider.overrideWithValue(depot),
        productRepositoryProvider.overrideWithValue(_Catalogue()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ProductCommentsModal(productId: 'produit-1')),
      ),
    ),
  );
  await _avancer(tester);
}

Future<void> _commenter(WidgetTester tester, String texte) async {
  await tester.enterText(find.byType(TextField), texte);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await _avancer(tester);
}

void main() {
  setUp(() {
    // La zone de saisie crée un enregistreur audio natif : sans plateforme,
    // son canal répond simplement.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });

  testWidgets('un commentaire refusé par la base le dit', (tester) async {
    final depot = _Commentaires(
      refus: const PostgrestException(message: _refus, code: 'P0001'),
    );
    await _ouvrir(tester, depot);

    await _commenter(tester, 'Une question de plus');

    expect(find.text(_refus), findsOneWidget);
    expect(depot.envois, isEmpty);
  });

  testWidgets('un commentaire accepté ne montre rien', (tester) async {
    final depot = _Commentaires();
    await _ouvrir(tester, depot);

    await _commenter(tester, 'Disponible en noir ?');

    expect(depot.envois, ['Disponible en noir ?']);
    expect(find.byType(SnackBar), findsNothing);
  });
}
