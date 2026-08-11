import 'package:intl/intl.dart';

/// Formats integer FCFA amounts (the currency has no subunits in practice)
/// with a French thousands separator, e.g. `12500` -> `12 500 FCFA`.
abstract final class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('fr_FR');

  static String formatFcfa(int amountFcfa) =>
      '${_formatter.format(amountFcfa)} FCFA';
}
