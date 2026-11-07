/// Comparer deux textes comme un humain les lit.
///
/// Le catalogue malien est plein de mots accentués — bògòlan, Ségou, karité,
/// sésame — et personne ne tape les accents sur un clavier de téléphone.
/// Un `contains` sur les chaînes brutes fait donc échouer la recherche la
/// plus naturelle : « segou » ne trouve pas « Ségou », et le fournisseur
/// conclut que la recherche ne marche pas.
///
/// La base fait déjà ce travail de son côté (`unaccent`, posé par `0081`).
/// Ceci en est le pendant pour les filtres qui s'appliquent en mémoire, sur
/// une liste déjà chargée.
library;

/// Les caractères accentués qu'on rencontre en français et dans les langues
/// du Mali transcrites en alphabet latin, et leur équivalent sans accent.
///
/// Une table explicite plutôt qu'une normalisation Unicode : Dart n'expose
/// pas NFD dans sa bibliothèque standard, et importer un paquet pour
/// soixante caractères serait disproportionné. Les voyelles à point souscrit
/// (ɛ, ɔ, ɲ, ŋ) sont incluses parce qu'elles apparaissent en bambara écrit.
const Map<String, String> _folding = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ɛ': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ñ': 'n', 'ɲ': 'n', 'ŋ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ɔ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Met un texte sous une forme comparable : minuscules, sans accents, sans
/// espaces superflus.
String normalizeForSearch(String value) {
  final lower = value.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_folding[character] ?? character);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// [haystack] contient-il [needle], accents et casse mis de côté ?
///
/// Une requête vide correspond à tout : c'est l'état d'un champ de recherche
/// qu'on n'a pas encore rempli, et il ne doit rien masquer.
bool matchesSearch(String haystack, String needle) {
  final query = normalizeForSearch(needle);
  if (query.isEmpty) return true;
  return normalizeForSearch(haystack).contains(query);
}

/// Vrai si **l'un** des textes correspond. Pour chercher à la fois dans un
/// nom et dans une description sans écrire la même condition deux fois.
bool matchesAnySearch(Iterable<String?> haystacks, String needle) {
  final query = normalizeForSearch(needle);
  if (query.isEmpty) return true;
  for (final haystack in haystacks) {
    if (haystack != null && normalizeForSearch(haystack).contains(query)) {
      return true;
    }
  }
  return false;
}

/// Où [needle] apparaît dans [haystack], accents et casse mis de côté :
/// `(début, fin)` en positions de [haystack], pour en mettre la partie
/// trouvée en valeur. `null` s'il n'y apparaît pas, ou si [needle] est vide.
///
/// Les positions sont celles du texte d'origine, pas du texte replié : « œ »
/// se replie en deux lettres, et un décalage ferait souligner à côté.
(int, int)? searchMatchRange(String haystack, String needle) {
  final cherche = normalizeForSearch(needle);
  if (cherche.isEmpty) return null;

  // Le texte replié, et pour chacun de ses caractères la position d'origine
  // dont il vient.
  final replie = StringBuffer();
  final origines = <int>[];
  var position = 0;
  for (final rune in haystack.runes) {
    final caractere = String.fromCharCode(rune);
    final plie = _folding[caractere.toLowerCase()] ?? caractere.toLowerCase();
    for (var i = 0; i < plie.length; i++) {
      origines.add(position);
    }
    replie.write(plie);
    position += caractere.length;
  }
  // Mêmes espaces que `normalizeForSearch` : simples, et sans bord.
  final texte = replie.toString();
  final debut = texte.indexOf(cherche);
  if (debut < 0) return null;
  final dernier = debut + cherche.length - 1;
  final fin = dernier + 1 < origines.length ? origines[dernier + 1] : haystack.length;
  return (origines[debut], fin);
}

