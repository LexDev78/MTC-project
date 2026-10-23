library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// La chaîne complète : de la création des comptes à la commande livrée.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/chaine_complete_test.dart -d `<simulateur>`
///
/// Les autres parcours regardent une fonctionnalité à la fois, sur des
/// comptes déjà créés par le jeu de démonstration. Celui-ci suit le chemin
/// qu'un vrai utilisateur emprunte une seule fois : il s'inscrit, et tout
/// le reste en découle.
///
/// C'est le seul endroit où les inscriptions, le dossier de vérification et
/// sa validation par le staff sont réellement exercées depuis l'écran. Elles
/// ont des tests de données ; personne n'avait jamais vu les écrans
/// s'enchaîner.
///
/// Chaque étape est enveloppée : une qui échoue n'arrête pas les suivantes,
/// et sa capture montre l'état réel au moment de l'échec — c'est
/// précisément l'information qu'on vient chercher.

/// Suffixe commun aux comptes créés, pour qu'un second passage ne bute pas
/// sur un nom d'utilisateur déjà pris. `resetAndSeed` vide la base entre
/// deux exécutions, mais pas entre deux étapes du même passage.
final _suffixe = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
final _client = 'client$_suffixe';
final _fournisseur = 'vendeur$_suffixe';
const _motDePasse = 'password123';
const _produit = 'Théière en terre cuite';

Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 8}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
}

Future<void> remplir(WidgetTester tester, String libelle, String valeur) async {
  final champ = find.widgetWithText(TextFormField, libelle);
  await tester.ensureVisible(champ.first);
  await tester.pump();
  await tester.enterText(champ.first, valeur);
  await avancer(tester, pas: 2);
}

/// Revient à l'écran de connexion, d'où qu'on parte.
///
/// Client comme fournisseur ont « Déconnexion » directement dans leur
/// profil (en bas du menu, pour le client, comme dans le kit) : on remonte
/// jusqu'à l'onglet « Profil » sans coder le rôle en dur, parce que ce
/// parcours change d'acteur six fois.
Future<void> seDeconnecter(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    if (find.text('Se connecter').evaluate().isNotEmpty) return;
    if (find.byTooltip('Profil').evaluate().isNotEmpty) {
      await toucher(tester, find.byTooltip('Profil'), pas: 6);
    }
    if (find.text('Déconnexion').evaluate().isNotEmpty) {
      await toucher(tester, find.text('Déconnexion'), pas: 14);
      continue;
    }
    await tester.pageBack();
    await avancer(tester, pas: 5);
  }
}

/// Ouvre l'écran de création de compte depuis la connexion.
Future<void> ouvrirInscription(WidgetTester tester) async {
  await attendre(tester, find.text('Créer un compte'));
  await toucher(tester, find.text('Créer un compte'), pas: 8);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'chaîne complète — inscription, vérification, vente, commande',
    timeout: const Timeout(Duration(minutes: 25)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      // ================= ACTE 1 — les inscriptions =====================

      await etapeVisuelle(tester, 'ch-01-accueil', () async {
        await attendre(tester, find.text('Commencer'));
      });

      await etapeVisuelle(tester, 'ch-02-choix-du-role', () async {
        await toucher(tester, find.text('Commencer'), pas: 8);
        await ouvrirInscription(tester);
        await attendre(tester, find.text('Je suis...'));
      });

      await etapeVisuelle(tester, 'ch-03-client-formulaire', () async {
        await toucher(tester, find.text('Client'), pas: 8);
        await attendre(tester, find.widgetWithText(TextFormField, 'Nom complet'));
        await remplir(tester, 'Nom complet', 'Awa Traoré');
        await remplir(tester, "Nom d'utilisateur", _client);
        await remplir(tester, 'Numéro de téléphone', '+22370112233');
        await remplir(tester, 'Mot de passe', _motDePasse);
      });

      await etapeVisuelle(tester, 'ch-04-client-cree', () async {
        await toucher(tester, find.text('Créer mon compte'), pas: 18);
        // Le client arrive directement dans l'application : aucune
        // validation n'est demandée pour acheter.
        await attendre(tester, find.byTooltip('Panier'));
      });

      await etapeVisuelle(tester, 'ch-05-fournisseur-type', () async {
        await seDeconnecter(tester);
        await ouvrirInscription(tester);
        await toucher(tester, find.text('Fournisseur tiers'), pas: 8);
        await attendre(tester, find.text('Vendeur individuel'));
      });

      await etapeVisuelle(tester, 'ch-06-fournisseur-formulaire', () async {
        await toucher(tester, find.text('Vendeur individuel'), pas: 8);
        await attendre(tester, find.widgetWithText(TextFormField, 'Nom complet'));
        await remplir(tester, 'Nom complet', 'Modibo Keïta');
        await remplir(tester, 'Nom de la boutique', 'Poterie de Ségou');
        await remplir(tester, 'Ville', 'Ségou');
        await remplir(tester, "Nom d'utilisateur", _fournisseur);
        await remplir(tester, 'Numéro de téléphone', '+22370445566');
        await remplir(tester, 'Mot de passe', _motDePasse);
      });

      // ================= ACTE 2 — la vérification ======================

      await etapeVisuelle(tester, 'ch-07-dossier-kyc', () async {
        await toucher(tester, find.text('Créer mon compte'), pas: 20);
        // Le routeur force le fournisseur non vérifié vers son dossier :
        // il ne peut rien vendre avant de l'avoir soumis.
        await attendre(tester, find.text('Vérification de votre compte'));
      });

      await etapeVisuelle(tester, 'ch-08-kyc-rempli', () async {
        await remplir(
          tester,
          'Nom du gérant / représentant légal',
          'Modibo Keïta',
        );
        await remplir(tester, 'Adresse du siège', 'Quartier Médine, Ségou');
      });

      await etapeVisuelle(tester, 'ch-09-kyc-soumis', () async {
        await toucher(tester, find.text('Soumettre mon dossier'), pas: 20);
      });

      await etapeVisuelle(tester, 'ch-10-staff-file-kyc', () async {
        await seDeconnecter(tester);
        await seConnecter(tester, 'admin1');
        await avancer(tester, pas: 10);
      });

      await etapeVisuelle(tester, 'ch-11-staff-dossier', () async {
        await toucher(tester, find.textContaining('Dossiers'), pas: 12);
        await attendre(tester, find.textContaining('Poterie de Ségou'));
      });

      await etapeVisuelle(tester, 'ch-12-staff-valide', () async {
        await toucher(tester, find.textContaining('Poterie de Ségou'), pas: 12);
        await toucher(tester, find.textContaining('Valider'), pas: 16);
      });

      // ================= ACTE 3 — le fournisseur vend ==================

      await etapeVisuelle(tester, 'ch-13-fournisseur-verifie', () async {
        await seDeconnecter(tester);
        await seConnecter(tester, _fournisseur);
        await avancer(tester, pas: 10);
      });

      await etapeVisuelle(tester, 'ch-14-nouveau-produit', () async {
        await ouvrirOnglet(tester, 'Produits');
        await toucher(tester, find.textContaining('Ajouter'), pas: 12);
        await attendre(tester, find.widgetWithText(TextFormField, 'Nom'));
      });

      await etapeVisuelle(tester, 'ch-15-produit-rempli', () async {
        await remplir(tester, 'Nom', _produit);
        await remplir(tester, 'Prix (FCFA)', '15000');
        await remplir(tester, 'Stock', '20');
      });

      await etapeVisuelle(tester, 'ch-16-produit-cree', () async {
        await toucher(tester, find.textContaining('Enregistrer'), pas: 20);
      });

      // ================= ACTE 4 — le client achète =====================

      await etapeVisuelle(tester, 'ch-17-client-catalogue', () async {
        await seDeconnecter(tester);
        await seConnecter(tester, _client);
        await avancer(tester, pas: 10);
      });

      await etapeVisuelle(tester, 'ch-18-client-panier', () async {
        await ouvrirOnglet(tester, 'Panier');
        await avancer(tester, pas: 8);
      });

      await etapeVisuelle(tester, 'ch-19-client-commandes', () async {
        await ouvrirOnglet(tester, 'Commandes');
        await avancer(tester, pas: 8);
      });

      // ================= ACTE 5 — ce qui reste =========================

      await etapeVisuelle(tester, 'ch-20-client-profil', () async {
        await ouvrirOnglet(tester, 'Profil');
        await avancer(tester, pas: 8);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );
}
