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

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 6) return '6 caractères minimum';
    return null;
  }
}
