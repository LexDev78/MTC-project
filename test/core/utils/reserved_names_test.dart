import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/utils/reserved_names.dart';

// La même liste que la vérification de `0144` côté base : les deux règles
// doivent rendre la même réponse, l'app ne faisant qu'anticiper la base.
void main() {
  const reserves = [
    'MTC Officiel', 'mtc officiel', 'M.T.C Officiel', 'M T C', 'mtc-shop',
    'MTCofficiel', 'Support MTC', 'Service client MTC', 'ＭＴＣ',
    'МТС Officiel', 'Mali Trade Connect', 'MaliTradeConnect',
    'Mali-Trade-Connect Bamako', 'Service client', 'Administrateur', 'Admin',
    'Équipe', 'Admin MTC',
    // Ce que la contre-vérification du 06/11/2026 a fait passer à la
    // première version : invisibles, diacritique combinant, petites
    // capitales, cyrillique, mots coupés.
    'Service client M\u200BTC', '\u0405ervice client M\u200BTC',
    'M\u0336TC Officiel', 'MT\uFEFFC', 'ᴍᴛᴄ officiel', 'M TC Officiel',
    'MT-C Shop', 'rnTC', 'M🙂TC', '\u0405upport',
  ];
  const libres = [
    'Karim T. Coulibaly', 'Fatim Tcham', 'Awa Traoré', 'Bogolan Bamako',
    'Électro Bamako', 'Service Plus Bamako', 'Alimentation Ségou',
    'Matériaux Koutiala', 'Moussa Diarra', 'Tissus Mopti', 'Aïssata Sangaré',
    'A. M. Traoré', 'Mamadou Tcheka', 'M. Traoré', 'Fournier',
    'Kadiatou Camara', 'Mohamed Tall',
  ];

  for (final nom in reserves) {
    test('« $nom » est réservé', () => expect(isReservedPublicName(nom), isTrue));
  }
  for (final nom in libres) {
    test('« $nom » est libre', () => expect(isReservedPublicName(nom), isFalse));
  }

  test('la forme normalisée est celle de la base', () {
    expect(normalizedPublicName('M.T.C Officiel'), 'mtc officiel');
    expect(normalizedPublicName('Karim T. Coulibaly'), 'karim t coulibaly');
    expect(normalizedPublicName('A. M. Traoré'), 'am traore');
    expect(normalizedPublicName('МТС Officiel'), 'mtc officiel');
  });
}
