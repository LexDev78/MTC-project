import 'package:intl/intl.dart';

/// Date/time formatting helpers. Uses explicit numeric patterns (not named
/// locale formats) so no `initializeDateFormatting` call is required.
abstract final class DateFormatter {
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _time = DateFormat('HH:mm');

  // dart format off
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const _weekdaysShort = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  static const _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];
  // dart format on

  static String formatDateTime(DateTime value) => _dateTime.format(value);

  static String formatDate(DateTime value) => _date.format(value);

  static String formatTime(DateTime value) => _time.format(value);

  /// "16 août" — hardcoded French month names (rather than a locale-aware
  /// `DateFormat`) so no `initializeDateFormatting` call is required, same
  /// reasoning as the rest of this class.
  static String formatDayMonth(DateTime value) =>
      '${_jour(value.day)} ${_months[value.month - 1]}';

  /// Le premier du mois s'écrit « 1er » : « 1 octobre » se lit comme une
  /// faute.
  static String _jour(int day) => day == 1 ? '1er' : '$day';

  /// « 21 octobre 2026 ».
  static String formatDayMonthYear(DateTime value) =>
      '${formatDayMonth(value)} ${value.year}';

  /// « mardi 21 octobre 2026 ».
  static String formatLongDate(DateTime value) =>
      '${_weekdays[value.weekday - 1]} ${formatDayMonthYear(value)}';

  /// « Aujourd'hui », « Hier », sinon la date longue : l'en-tête d'un
  /// historique groupé par jour.
  static String dayHeading(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    // En UTC : d'un minuit local à l'autre, un passage à l'heure d'été
    // ferait 23 heures, soit « 0 jour ».
    final jour = DateTime.utc(value.year, value.month, value.day);
    final aujourdhui = DateTime.utc(
      reference.year,
      reference.month,
      reference.day,
    );
    final ecart = aujourdhui.difference(jour).inDays;
    if (ecart == 0) return 'Aujourd\'hui – ${formatLongDate(value)}';
    if (ecart == 1) return 'Hier – ${formatLongDate(value)}';
    return formatLongDate(value);
  }

  /// "dim." for a Sunday, etc.
  static String weekdayShort(DateTime value) =>
      _weekdaysShort[value.weekday - 1];

  /// French relative time, e.g. "à l'instant", "il y a 5 min", "il y a 2 j".
  static String relative(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(value);

    if (diff.inSeconds < 60) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return formatDate(value);
  }
}
