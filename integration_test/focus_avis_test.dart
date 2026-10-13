library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « avis » : ce qu'un acheteur dépose, et ce que les autres en
/// voient sur la fiche produit.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_avis_test.dart -d `<simulateur>`
///
/// Trois choses ne se voient qu'en image : un avis avec ses photos au
/// milieu d'une fiche produit, la distinction visuelle entre un commentaire
/// d'acheteur et une réponse du vendeur, et le formulaire d'avis avec ses
/// boutons d'ajout de médias.
///
/// L'avis illustré est **semé** (RPC + dépôt des fichiers), pas déposé par
/// l'interface : le sélecteur de photos est une feuille native, qu'aucun
/// test ne peut piloter. C'est donc le rendu qui est vérifié ici, pas la
/// cueillette — et c'est dit, plutôt que laissé à supposer.
const _produit = 'Tissu Bogolan traditionnel';
const _clientAwa = '04060d99-e34d-520e-8b75-631ff4d3c10c';
const _groupeAwaBogolan = 'efbd44fe-a725-533d-ba6c-a9c867b161cb';

Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 6}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
}

Future<void> revenirAuShell(WidgetTester tester, String infobulle) async {
  for (var i = 0; i < 3; i++) {
    if (find.byTooltip(infobulle).evaluate().isNotEmpty) return;
    await tester.pageBack();
    await avancer(tester, pas: 5);
  }
}

/// Dépose un avis illustré au nom d'Awa, avec de vraies images.
Future<void> semerAvisIllustre() async {
  final image = await rootBundle.load(
    'assets/images/products/textiles/fabric.jpg',
  );
  final bytes = image.buffer.asUint8List();
  final chemins = <String>[];
  for (var i = 0; i < 2; i++) {
    final chemin = '$_clientAwa/avis-$i.jpg';
    await uploadToBucketAsAdmin(
      bucket: 'review-media',
      path: chemin,
      bytes: bytes,
    );
    chemins.add(chemin);
  }

  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail('client1'),
    password: 'password123',
  );
  final groupe = await client
      .from('order_supplier_groups')
      .select('order_id')
      .eq('id', _groupeAwaBogolan)
      .single();
  await client.rpc(
    'submit_review',
    params: {
      'p_order_id': groupe['order_id'],
      'p_supplier_group_id': _groupeAwaBogolan,
      'p_stars': 4,
      'p_comment': 'Tissu conforme à la photo, couleurs très vives. '
          'Voici ce que j\'ai reçu.',
      'p_image_paths': chemins,
    },
  );
  await client.dispose();
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
    await semerAvisIllustre();
  });

  testWidgets(
    'focus avis — photos d\'acheteur, commentaires, réponse du vendeur',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      await etapeVisuelle(tester, 'avis-01-section', () async {
        await seConnecter(tester, 'client2');
        await attendre(tester, find.text('Rechercher un produit...'));
        await toucher(tester, find.text('Rechercher un produit...'));
        await tester.enterText(find.byType(TextField).first, 'Bogolan tradition');
        await avancer(tester, pas: 10);
        await attendre(tester, find.byType(ProductCard));
        await toucher(tester, find.byType(ProductCard).first, pas: 12);
        await attendre(tester, find.byType(ProductDetailScreen));
        await attendre(tester, find.text('Avis des acheteurs'));
        await cadrer(tester, find.text('Avis des acheteurs'), alignement: 0.1);
        expect(find.text('Awa Traoré'), findsWidgets);
      });

      await etapeVisuelle(tester, 'avis-02-composer-commentaire', () async {
        await toucher(tester, find.text('Commenter').first, pas: 10);
        await attendre(tester, find.text('Commenter cet avis'));
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Vidéo'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'avis-03-commentaire-publie', () async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Votre commentaire').first,
          'Le tissu est-il épais ? Je cherche de quoi faire un boubou.',
        );
        await avancer(tester, pas: 3);
        await toucher(tester, find.text('Publier'), pas: 12);
        await attendre(tester, find.textContaining('Le tissu est-il épais'));
        await cadrer(tester, find.textContaining('Le tissu est-il épais'));
        expect(find.textContaining('Le tissu est-il épais'), findsWidgets);
      });

      // Le formulaire d'avis et ses boutons de médias, depuis une commande
      // livrée encore sans avis.
      await etapeVisuelle(tester, 'avis-04-formulaire', () async {
        await revenirAuShell(tester, 'Profil');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Mes commandes'), pas: 12);
        await attendre(tester, find.textContaining('Ségou'));
        await toucher(tester, find.textContaining('Ségou'), pas: 12);
        await attendre(tester, find.text('Laisser un avis'));
        await toucher(tester, find.text('Laisser un avis'), pas: 12);
        await attendre(tester, find.text('Ajouter des photos'));
        expect(find.text('Ajouter des photos'), findsOneWidget);
      });

      // Côté vendeur : ce qu'il voit d'un avis illustré. C'est sa seule vue
      // des avis — son app n'offre pas le catalogue public, donc il répond
      // par « Réponse du vendeur » et non par un commentaire.
      await etapeVisuelle(tester, 'avis-05-cote-vendeur', () async {
        await revenirAuShell(tester, 'Profil');
        await ouvrirOnglet(tester, 'Profil');
        // La déconnexion d'un client est dans « Paramètres », pas sur la
        // page de profil elle-même.
        await toucher(tester, find.text('Paramètres'), pas: 10);
        await toucher(tester, find.text('Déconnexion'), pas: 12);
        await seConnecter(tester, 'fournisseur1');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.byTooltip('Avis clients'), pas: 12);
        await attendre(tester, find.textContaining('couleurs très vives'));
        await cadrer(tester, find.textContaining('couleurs très vives'));
        expect(find.textContaining('couleurs très vives'), findsWidgets);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );
}
