@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../support/supabase_test_harness.dart';

// Ce que chaque rôle ne doit pas **voir**.
//
// Le pendant de `write_boundaries_test.dart`, et il manquait. Toute une
// série de permissions a été posée sur les écritures en laissant les
// lectures ouvertes — un collaborateur sans droit sur les remises les
// voyait quand même, et voyait aussi les demandes de retrait de son patron,
// montants et numéros Mobile Money compris.
//
// Une permission qui n'empêche que d'écrire n'est pas une permission : voir
// suffit à nuire, et parfois c'est tout ce qu'on cherchait.
//
// Les lectures RLS **filtrent** au lieu de lever : une requête interdite
// rend zéro ligne, elle n'échoue pas. C'est donc le nombre de lignes qu'on
// vérifie, jamais une exception — sauf pour les RPC, qui peuvent refuser
// franchement.

Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

/// Vérifie qu'une table ne rend **rien** à ce client.
///
/// Deux formes de fermeture coexistent dans ce schéma, et les deux sont
/// bonnes : la policy filtre (zéro ligne), ou le droit de table manque
/// (`permission denied`, plus strict encore). C'est l'effet qui compte, pas
/// la mécanique — même raisonnement que `write_boundaries_test.dart`.
Future<void> _neVoitRien(SupabaseClient client, String table) async {
  try {
    expect(
      await client.from(table).select(),
      isEmpty,
      reason: '$table ne doit rien rendre à ce compte',
    );
  } on PostgrestException {
    // Refusé d'emblée : c'est la fermeture la plus franche.
  }
}

Future<SupabaseClient> _anonyme() async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  return client;
}

void main() {
  setUp(resetAndSeed);

  group('un client ne voit pas ce qui appartient aux boutiques', () {
    test('ni les demandes de retrait, ni les réglages financiers', () async {
      final client = await _connecte('client1');
      await _neVoitRien(client, 'payout_requests');
      await _neVoitRien(client, 'supplier_finance_settings');
    });

    test('ni les dossiers de vérification', () async {
      // Pièces d'identité, numéros RCCM, adresses de siège : le dossier
      // d'un fournisseur n'appartient qu'à lui et au staff.
      final client = await _connecte('client1');
      await _neVoitRien(client, 'supplier_kyc');
    });

    test('ni les équipes des boutiques', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'equipier1',
        permissions: const {'products'},
      );
      final client = await _connecte('client1');
      await _neVoitRien(client, 'supplier_collaborators');
    });

    test('ni les codes promo en vigueur', () async {
      // Les énumérer reviendrait à s'offrir les remises qu'on ne lui a pas
      // adressées (`0071`).
      final client = await _connecte('client1');
      await _neVoitRien(client, 'promo_codes');
    });

    test('ni les produits qu\'un fournisseur n\'a pas publiés', () async {
      final client = await _connecte('client1');
      final brouillons = await client
          .from('products')
          .select('id')
          .neq('status', 'active');
      expect(brouillons, isEmpty);
    });
  });

  group('un client ne voit pas ce qui appartient à un autre client', () {
    test('ni son panier, ni ses adresses', () async {
      final autre = await _connecte('client2');
      final paniers = await autre
          .from('cart_items')
          .select('id')
          .neq('user_id', DemoIds.clientMoussa);
      expect(paniers, isEmpty);

      final adresses = await autre
          .from('addresses')
          .select('id')
          .neq('user_id', DemoIds.clientMoussa);
      expect(adresses, isEmpty);
    });

    test('ni ses commandes', () async {
      final autre = await _connecte('client2');
      final commandes = await autre
          .from('orders')
          .select('id, client_id')
          .neq('client_id', DemoIds.clientMoussa);
      expect(commandes, isEmpty);
    });

    test('ni ses conversations', () async {
      final autre = await _connecte('client2');
      final fils = await autre
          .from('chat_conversations')
          .select('id, client_id')
          .neq('client_id', DemoIds.clientMoussa);
      expect(fils, isEmpty);
    });
  });

  group('un fournisseur ne voit pas la boutique du voisin', () {
    test('ni ses codes promo, ni ses retraits', () async {
      final voisin = await _connecte('fournisseur2');

      final codes = await voisin
          .from('promo_codes')
          .select('id')
          .eq('supplier_id', DemoIds.supplierBogolanBamako);
      expect(codes, isEmpty);

      final retraits = await voisin
          .from('payout_requests')
          .select('id')
          .eq('supplier_id', DemoIds.supplierBogolanBamako);
      expect(retraits, isEmpty);
    });

    test('ni son dossier de vérification', () async {
      final voisin = await _connecte('fournisseur2');
      final dossiers = await voisin
          .from('supplier_kyc')
          .select('id')
          .eq('supplier_id', DemoIds.supplierBogolanBamako);
      expect(dossiers, isEmpty);
    });

    test('ni son équipe', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'equipier2',
        permissions: const {'products'},
      );
      final voisin = await _connecte('fournisseur2');
      expect(await voisin.rpc('fetch_my_collaborators'), isEmpty);
    });

    test('ni ses brouillons', () async {
      final voisin = await _connecte('fournisseur2');
      final brouillons = await voisin
          .from('products')
          .select('id')
          .eq('supplier_id', DemoIds.supplierBogolanBamako)
          .neq('status', 'active');
      expect(brouillons, isEmpty);
    });
  });

  group('un livreur ne voit que ses courses', () {
    test('il ne lit pas les retraits ni les codes promo', () async {
      final livreur = await _connecte('livreur1');
      await _neVoitRien(livreur, 'payout_requests');
      await _neVoitRien(livreur, 'promo_codes');
    });

    test('il n\'opère aucune boutique', () async {
      final livreur = await _connecte('livreur1');
      expect(await livreur.rpc('operating_supplier_id'), isNull);
      expect(await livreur.rpc('is_supplier_owner'), isFalse);
      expect(
        await livreur.rpc('supplier_can', params: {'p_permission': 'products'}),
        isFalse,
      );
    });
  });

  group('un visiteur anonyme', () {
    test('voit le catalogue publié, et rien d\'autre', () async {
      final anon = await _anonyme();

      final actifs = await anon.from('products').select('id, status');
      expect(actifs, isNotEmpty, reason: 'le catalogue doit rester public');
      for (final p in (actifs as List).cast<Map<String, dynamic>>()) {
        expect(p['status'], 'active');
      }

      for (final table in [
        'payout_requests',
        'promo_codes',
        'orders',
        'supplier_collaborators',
        'supplier_kyc',
        'cart_items',
        'addresses',
      ]) {
        await _neVoitRien(anon, table);
      }
    });

    test('n\'opère aucune boutique et n\'est pas du staff', () async {
      final anon = await _anonyme();
      expect(await anon.rpc('operating_supplier_id'), isNull);
      expect(await anon.rpc('is_staff'), isFalse);
    });
  });
}
