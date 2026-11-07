import 'reserved_names.dart';

/// Form validators shared across auth/profile/checkout forms. Malian mobile
/// numbers are 8 digits, optionally prefixed with the +223 country code.
abstract final class Validators {
  static final RegExp _maliPhone = RegExp(r'^(\+223)?[5-9]\d{7}$');

  static String? required(
    String? value, {
    String message = 'Ce champ est obligatoire',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? usernameOrPhone(String? value) =>
      required(value, message: 'Identifiant obligatoire');

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro est obligatoire';
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (!_maliPhone.hasMatch(normalized)) {
      return 'Numéro malien invalide (ex : 70 12 34 56)';
    }
    return null;
  }

  /// Un nom public — le nom affiché d'un compte, celui d'une boutique :
  /// obligatoire, et pas un nom réservé à MTC (`reserved_names.dart`,
  /// miroir de `0144`).
  static String? publicName(String? value) {
    final requis = required(value);
    if (requis != null) return requis;
    if (isReservedPublicName(value!)) {
      return 'Ce nom est réservé à MTC : choisissez-en un autre.';
    }
    return null;
  }

  /// À la connexion : un mot de passe saisi, rien de plus. La longueur
  /// minimale ne vaut que pour en choisir un — un compte créé quand elle
  /// était de 6 doit pouvoir se connecter avec le sien (`0151`).
  static String? passwordEntered(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    return null;
  }

  /// Pour choisir un mot de passe : 8 caractères au moins (`0151`).
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 8) return '8 caractères minimum';
    return null;
  }

  static String? positiveInteger(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est obligatoire';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Nombre invalide';
    return null;
  }

  static String? positiveDecimal(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est obligatoire';
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 'Nombre invalide';
    return null;
  }
}
