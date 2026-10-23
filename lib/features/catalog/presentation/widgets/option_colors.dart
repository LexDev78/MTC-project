import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/search_text.dart';

/// La teinte d'une couleur telle qu'un fournisseur l'a saisie (« Noir »,
/// « Bleu indigo », « Rouge bordeaux »), pour la pastille de la feuille
/// d'achat.
///
/// `null` quand le nom ne dit rien de connu : la pastille reste neutre, et
/// c'est le nom écrit dessous qui parle. Une teinte devinée à tort serait
/// pire qu'aucune — le client achèterait sur la foi de la pastille.
///
/// Le dernier mot reconnu l'emporte : en français la précision vient après
/// (« bleu **marine** », « vert **olive** »).
Color? teinteDeCouleur(String valeur) {
  final mots = normalizeForSearch(
    valeur,
  ).split(RegExp('[^a-z]+')).where((mot) => mot.isNotEmpty).toList();
  for (final mot in mots.reversed) {
    final teinte = _teintes[mot];
    if (teinte != null) return teinte;
  }
  return null;
}

/// Les teintes vives reprennent la palette des pastilles du kit
/// (`SelectedColors` : EA6262, B1CC63, FFBF5F, 9FE1DD, C482DB).
const _teintes = <String, Color>{
  'noir': Color(0xFF16161E),
  'noire': Color(0xFF16161E),
  'blanc': Color(0xFFFFFFFF),
  'blanche': Color(0xFFFFFFFF),
  'creme': Color(0xFFF6EEDC),
  'ecru': Color(0xFFF1E9D2),
  'beige': Color(0xFFE3D3B4),
  'gris': Color(0xFFA3A3AE),
  'grise': Color(0xFFA3A3AE),
  'argent': Color(0xFFC9CCD3),
  'argente': Color(0xFFC9CCD3),
  'argentee': Color(0xFFC9CCD3),
  'rouge': Color(0xFFEA6262),
  'bordeaux': Color(0xFF7D1F2C),
  'rose': Color(0xFFF2A7C3),
  'corail': Color(0xFFF08A6C),
  'saumon': Color(0xFFF4A38C),
  'orange': Color(0xFFF59A3C),
  'jaune': Color(0xFFFFBF5F),
  'moutarde': Color(0xFFD4A62A),
  'ocre': Color(0xFFC8862F),
  'or': Color(0xFFD4AF37),
  'dore': Color(0xFFD4AF37),
  'doree': Color(0xFFD4AF37),
  'vert': Color(0xFFB1CC63),
  'verte': Color(0xFFB1CC63),
  'kaki': Color(0xFF8A8B5A),
  'olive': Color(0xFF6F7537),
  'turquoise': Color(0xFF9FE1DD),
  'bleu': Color(0xFF4F7BD9),
  'bleue': Color(0xFF4F7BD9),
  'ciel': Color(0xFF9CCCF2),
  'marine': Color(0xFF1F2E5A),
  'indigo': Color(0xFF2E3A87),
  'violet': Color(0xFFC482DB),
  'violette': Color(0xFFC482DB),
  'mauve': Color(0xFFC9A3D6),
  'marron': Color(0xFF7A4B2A),
  'brun': Color(0xFF6B4226),
  'brune': Color(0xFF6B4226),
  'chocolat': Color(0xFF4E2E1B),
  'camel': Color(0xFFC19A6B),
};
