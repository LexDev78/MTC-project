import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// Le code à six chiffres qui fait d'une session staff une session staff
/// (`0135`).
///
/// Un compte MTC voit toutes les commandes, les pièces d'identité des
/// vendeurs et des livreurs, et décide des paiements : son mot de passe seul
/// n'ouvre plus rien. La première fois, on relie le compte à une application
/// d'authentification (Google Authenticator, Microsoft Authenticator,
/// Aegis…) en scannant un QR code ; ensuite, on saisit le code qu'elle
/// affiche à chaque connexion.
///
/// Le routeur immobilise ici, comme pour le mot de passe dicté par un
/// patron : aucun onglet, aucun retour. La seule sortie autre que le code
/// est la déconnexion.
class StaffMfaScreen extends ConsumerStatefulWidget {
  const StaffMfaScreen({super.key});

  @override
  ConsumerState<StaffMfaScreen> createState() => _StaffMfaScreenState();
}

class _StaffMfaScreenState extends ConsumerState<StaffMfaScreen> {
  static const _longueur = 6;

  final _code = TextEditingController();

  /// Le facteur déjà relié : on demande seulement le code.
  String? _facteurVerifie;

  /// Le facteur qu'on est en train de relier : on montre le QR code.
  TotpEnrollment? _enrolement;

  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _code.addListener(() {
      if (_erreur != null) setState(() => _erreur = null);
      // Le bouton suit le nombre de chiffres saisis.
      setState(() {});
    });
    _preparer();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _preparer() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final depot = ref.read(authRepositoryProvider);
    try {
      final facteur = await depot.fetchVerifiedTotpFactorId();
      final enrolement = facteur == null ? await depot.enrollTotp() : null;
      if (!mounted) return;
      setState(() {
        _facteurVerifie = facteur;
        _enrolement = enrolement;
      });
    } on ValidationException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (erreur) {
      if (mounted) {
        setState(
          () => _erreur = messagePourUtilisateur(
            erreur,
            repli: 'La double authentification n\'a pas pu démarrer.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _valider() async {
    final facteur = _facteurVerifie ?? _enrolement?.factorId;
    if (facteur == null || _envoi) return;
    if (_code.text.length != _longueur) {
      setState(() => _erreur = 'Saisissez les six chiffres affichés.');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final depot = ref.read(authRepositoryProvider);
    try {
      await depot.verifyTotp(factorId: facteur, code: _code.text);
      // La session est passée en `aal2` : le compte relu n'a plus de code en
      // attente, et le routeur mène à l'accueil du staff.
      await depot.reloadCurrentUser();
    } on ValidationException catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() => _erreur = e.message);
    } catch (erreur) {
      if (!mounted) return;
      setState(
        () => _erreur = messagePourUtilisateur(
          erreur,
          repli: 'Le code n\'a pas pu être vérifié. Réessayez.',
        ),
      );
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final enrolement = _enrolement;
    final pret = _facteurVerifie != null || enrolement != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Double authentification'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _chargement
            ? const MtcLoadingView()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      enrolement != null
                          ? 'Reliez votre compte à une application'
                          : 'Le code de votre application',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      enrolement != null
                          ? 'Un compte MTC voit les commandes, les pièces '
                                'd\'identité et les versements : son mot de passe '
                                'ne suffit pas. Ouvrez une application '
                                'd\'authentification (Google Authenticator, '
                                'Microsoft Authenticator, Aegis…), scannez ce '
                                'code, puis saisissez les six chiffres qu\'elle '
                                'affiche.'
                          : 'Saisissez les six chiffres qu\'affiche votre '
                                'application d\'authentification pour MTC.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (enrolement != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _CodeARelier(enrolement: enrolement),
                    ],
                    if (pret) ...[
                      const SizedBox(height: AppSpacing.lg),
                      CodeInputField(
                        controller: _code,
                        length: _longueur,
                        hasError: _erreur != null,
                        enabled: !_envoi,
                        onCompleted: (_) => _valider(),
                      ),
                    ],
                    if (_erreur case final erreur?) ...[
                      const SizedBox(height: AppSpacing.md),
                      MtcErrorBanner(erreur),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (pret)
                      MtcPrimaryButton(
                        label: 'Valider',
                        isLoading: _envoi,
                        onPressed: _code.text.length == _longueur && !_envoi
                            ? _valider
                            : null,
                      )
                    else
                      // L'enrôlement a échoué : rien à valider, mais un
                      // nouvel essai possible plutôt qu'un écran figé.
                      OutlinedButton.icon(
                        onPressed: _preparer,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Téléphone perdu ? Un administrateur MTC peut retirer '
                      'l\'ancienne liaison pour que vous en créiez une neuve.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Le QR code à scanner, et la clé à saisir à la main pour qui ne peut pas
/// scanner — un seul téléphone, qui affiche l'app et doit aussi lire le code.
class _CodeARelier extends StatelessWidget {
  const _CodeARelier({required this.enrolement});

  final TotpEnrollment enrolement;

  /// La clé par groupes de quatre : elle se recopie sans s'y perdre.
  String get _cleLisible {
    final cle = enrolement.secret;
    return [
      for (var i = 0; i < cle.length; i += 4)
        cle.substring(i, i + 4 > cle.length ? cle.length : i + 4),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Noir sur blanc dans les deux thèmes : un lecteur de QR code ne
            // lit pas un code clair sur fond sombre. Même choix que le code de
            // remise d'une course (`delivery_code_qr.dart`).
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: QrImageView(
                data: enrolement.uri,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Impossible de scanner ? Saisissez cette clé dans l\'application :',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: SelectableText(
                    _cleLisible,
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier la clé',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: enrolement.secret));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clé copiée.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
