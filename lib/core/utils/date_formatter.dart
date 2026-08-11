import 'package:intl/intl.dart';

/// Date/time formatting helpers. Uses explicit numeric patterns (not named
/// locale formats) so no `initializeDateFormatting` call is required.
abstract final class DateFormatter {
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _time = DateFormat('HH:mm');

  static String formatDateTime(DateTime value) => _dateTime.format(value);

  static String formatDate(DateTime value) => _date.format(value);

  static String formatTime(DateTime value) => _time.format(value);

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
