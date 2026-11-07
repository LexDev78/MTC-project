import 'package:intl/intl.dart';

/// Formats integer FCFA amounts (the currency has no subunits in practice)
/// with a French thousands separator, e.g. `12500` -> `12 500 FCFA`.
abstract final class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('fr_FR');

  /// L'espace insécable ordinaire (U+00A0), et non l'espace fine (U+202F)
  /// que `intl` met entre les milliers en français : la police du côté
  /// client (Plus Jakarta) n'a pas l'espace fine, le moteur la prenait dans
  /// une autre police, et « 55 250 F » se lisait « 55250 F ». Insécable
  /// aussi devant l'unité, pour qu'un prix ne se coupe pas en fin de ligne.
  static const _espace = ' ';

  /// `12500` -> `12 500`, sans unité : un ancien prix barré se lit comme
  /// une comparaison, pas comme un montant.
  static String formatAmount(int amountFcfa) =>
      _formatter.format(amountFcfa).replaceAll(' ', _espace);

  static String formatFcfa(int amountFcfa) =>
      '${formatAmount(amountFcfa)}${_espace}FCFA';

  /// `12500` -> `12 500 F` : la forme courte, pour les cartes produit du
  /// côté client, où « FCFA » plus l'ancien prix barré ne tiennent pas dans
  /// 140 points. « F » se lit franc CFA partout au Mali.
  static String formatFcfaCompact(int amountFcfa) =>
      '${formatAmount(amountFcfa)}${_espace}F';
}
