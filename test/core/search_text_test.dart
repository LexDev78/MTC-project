library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mtc_app/core/utils/search_text.dart';

/// La recherche en mémoire doit se comporter comme celle de la base, qui
/// ignore les accents depuis `0081`. Sans cela, le fournisseur qui tape
/// « segou » sur son téléphone ne trouve pas « Ségou » et conclut que la
/// recherche est cassée.
void main() {
  test('les accents ne font pas échouer la recherche', () {
    expect(matchesSearch('Tissu Bògòlan traditionnel', 'bogolan'), isTrue);
    expect(matchesSearch('Riz de Ségou', 'segou'), isTrue);
    expect(matchesSearch('Beurre de karité', 'karite'), isTrue);
    // Et dans l'autre sens : taper les accents doit marcher aussi.
    expect(matchesSearch('Riz de Segou', 'ségou'), isTrue);
  });

  test('les caractères du bambara écrit sont repliés', () {
    expect(matchesSearch('Bɔgɔlanfini', 'bogolanfini'), isTrue);
    expect(matchesSearch('Ɲɛnajɛ', 'nenaje'), isTrue);
  });

  test('la casse et les espaces en trop sont ignorés', () {
    expect(matchesSearch('SAC EN BOGOLAN', '  sac  '), isTrue);
    expect(matchesSearch('Sac   en    bogolan', 'sac en bogolan'), isTrue);
  });

  test('une requête vide ne masque rien', () {
    expect(matchesSearch('N\'importe quoi', ''), isTrue);
    expect(matchesSearch('N\'importe quoi', '   '), isTrue);
  });

  test('ce qui ne correspond pas est bien écarté', () {
    expect(matchesSearch('Tissu bogolan', 'smartphone'), isFalse);
  });

  test('chercher dans plusieurs champs à la fois', () {
    expect(
      matchesAnySearch(['Tissu', 'Tissé à Ségou, teinture naturelle'], 'segou'),
      isTrue,
    );
    // Un champ absent ne doit pas faire échouer la comparaison.
    expect(matchesAnySearch(['Tissu', null], 'tissu'), isTrue);
    expect(matchesAnySearch([null, null], 'tissu'), isFalse);
  });
}
