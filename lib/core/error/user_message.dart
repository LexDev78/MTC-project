import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exceptions.dart';

/// La phrase à montrer à l'utilisateur pour [error] — jamais un code.
///
/// Les écrans affichaient `error.toString()`. Pour nos propres exceptions
/// c'était une phrase française ; pour tout le reste, c'était ce qu'on lit
/// dans une console : `PostgrestException(message: JSON object requested,
/// multiple (or no) rows returned, code: PGRST116, details: …)`. Un
/// collaborateur dont l'accès venait d'être retiré lisait exactement ça en
/// essayant de se connecter.
///
/// Une seule fonction, pour que tous les écrans parlent pareil : un message
/// qui dit **ce qui s'est passé et quoi faire**, sans code, sans anglais.
///
/// Deux sources sont déjà rédigées pour l'utilisateur et passent telles
/// quelles : nos [AppException], et les `raise exception '…'` de nos
/// fonctions SQL (code `P0001`), écrites en français exprès. Tout le reste
/// est traduit selon sa cause.
///
/// [repli] remplace le message générique quand la cause est inconnue : à
/// l'endroit où l'erreur survient, « La promotion n'a pas pu être créée »
/// en dit plus que « Une erreur est survenue ».
String messagePourUtilisateur(Object? error, {String? repli}) {
  final generique = repli ?? _generique;
  if (error == null) return generique;

  if (error is AppException) return error.message;

  if (error is PostgrestException) return _depuisPostgrest(error, generique);
  if (error is AuthException) return _depuisAuth(error);
  if (error is StorageException) return _depuisStockage(error);
  if (error is FunctionException) return _depuisFonction(error, generique);

  if (error is TimeoutException) return _lent;
  if (error is http.ClientException || _estErreurReseau(error)) {
    return _horsLigne;
  }

  // `throw Exception('Fichier trop volumineux…')` : le message est à nous,
  // seul le préfixe « Exception: » est de trop.
  final texte = error.toString();
  if (texte.startsWith('Exception: ')) {
    final message = texte.substring('Exception: '.length).trim();
    if (_estLisible(message)) return message;
  }

  return generique;
}

const _generique = 'Une erreur est survenue. Réessayez dans un instant.';
const _horsLigne =
    'Pas de connexion internet. Vérifiez votre réseau et réessayez.';
const _lent = 'Le serveur met trop de temps à répondre. Réessayez.';
const _interdit = 'Vous n\'avez pas l\'autorisation de faire cela.';

String _depuisPostgrest(PostgrestException e, String generique) {
  switch (e.code) {
    // `raise exception` de nos fonctions : déjà rédigé pour l'utilisateur.
    case 'P0001':
      return _estLisible(e.message) ? e.message : generique;
    // Droits et RLS.
    case '42501':
      return _interdit;
    // `.single()` sans ligne : l'élément n'existe plus, ou n'est plus
    // visible pour ce compte — deux cas qu'on ne distingue pas exprès.
    case 'PGRST116':
      return 'Élément introuvable, ou vous n\'y avez plus accès.';
    case '23505':
      return 'Cet élément existe déjà.';
    case '23503':
      return 'Cette opération touche des éléments liés qui l\'empêchent.';
    case '23514':
    case '22P02':
    case '22023':
      return 'Une des valeurs saisies n\'est pas acceptée.';
    case '57014':
      return _lent;
    case 'PGRST301':
    case 'PGRST302':
      return 'Votre session a expiré. Reconnectez-vous.';
  }
  // Message d'une politique RLS sans code exploitable.
  if (e.message.contains('row-level security')) return _interdit;
  if (e.message.toLowerCase().contains('jwt')) {
    return 'Votre session a expiré. Reconnectez-vous.';
  }
  return generique;
}

String _depuisAuth(AuthException e) {
  final message = e.message.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return 'Identifiants incorrects.';
  }
  if (message.contains('should be different')) {
    return 'Le nouveau mot de passe doit être différent de l\'actuel.';
  }
  if (e is AuthWeakPasswordException ||
      message.contains('at least') ||
      message.contains('weak')) {
    return 'Mot de passe trop faible : 6 caractères minimum.';
  }
  if (message.contains('jwt') ||
      message.contains('expired') ||
      message.contains('refresh token')) {
    return 'Votre session a expiré. Reconnectez-vous.';
  }
  if (message.contains('network') || message.contains('socket')) {
    return _horsLigne;
  }
  if (message.contains('rate limit') || e.statusCode == '429') {
    return 'Trop de tentatives. Patientez quelques minutes avant de réessayer.';
  }
  return 'L\'authentification a échoué. Réessayez.';
}

String _depuisStockage(StorageException e) {
  switch (e.statusCode) {
    case '400':
    case '403':
      return 'Vous n\'avez pas l\'autorisation d\'envoyer ce fichier ici.';
    case '404':
      return 'Fichier introuvable.';
    case '409':
      return 'Un fichier porte déjà ce nom. Réessayez.';
    case '413':
      return 'Fichier trop volumineux.';
  }
  return 'L\'envoi du fichier a échoué. Réessayez.';
}

String _depuisFonction(FunctionException e, String generique) {
  // Nos fonctions edge répondent `{"error": "…"}` en français.
  final details = e.details;
  if (details is Map && details['error'] is String) {
    final message = details['error'] as String;
    if (_estLisible(message)) return message;
  }
  // Le runtime des fonctions arrêté, ou la fonction pas encore servie.
  if (e.status == 503 || e.status == 404 || e.status == 502) {
    return 'Service momentanément indisponible. Réessayez dans un instant.';
  }
  if (e.status == 401 || e.status == 403) return _interdit;
  return generique;
}

/// Les erreurs d'entrée-sortie de `dart:io`, reconnues sans importer
/// `dart:io` — qui n'existe pas sur le web, où l'app tourne aussi.
bool _estErreurReseau(Object error) {
  final type = error.runtimeType.toString();
  return type == 'SocketException' ||
      type == 'HandshakeException' ||
      type == 'HttpException' ||
      type == 'TlsException';
}

/// Un message qu'on peut montrer tel quel : pas un nom de type, pas un
/// identifiant technique, pas de l'anglais de bibliothèque.
bool _estLisible(String message) {
  if (message.isEmpty || message.length > 240) return false;
  const indices = [
    'Exception',
    'Error(',
    'null check',
    'Instance of',
    'PGRST',
    'stack',
    'JSON object requested',
  ];
  return !indices.any(message.contains);
}
