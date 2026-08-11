import 'package:uuid/uuid.dart';

abstract final class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String next() => _uuid.v4();
}
