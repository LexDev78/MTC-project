import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// Ce que la première étape passe à celle-ci : le compte désigné, et le code
/// parti pour lui.
typedef ForgotPasswordCodeArgs = ({
  String identifier,
  PasswordResetRequest request,
});

/// Mot de passe oublié, seconde étape : le code reçu par e-mail et le
/// nouveau mot de passe (`reset_password_with_code`, `0127`).
///
/// Une fois changé, on est connecté aussitôt — avec l'identifiant que rend
/// le serveur, puisqu'on a pu venir par son adresse e-mail —, et le routeur
/// mène à l'accueil du compte. Les autres appareils, eux, sont déconnectés.
class ForgotPasswordCodeScreen extends ConsumerStatefulWidget {
  const ForgotPasswordCodeScreen({super.key, required this.args});

  /// `null` quand l'écran est ouvert sans la première étape (un lien, un
  /// rechargement) : il n'y a pas de code à donner.
  final ForgotPasswordCodeArgs? args;

  @override
  ConsumerState<ForgotPasswordCodeScreen> createState() =>
      _ForgotPasswordCodeScreenState();
}

class _ForgotPasswordCodeScreenState
    extends ConsumerState<ForgotPasswordCodeScreen>
    with ResendCountdown {
  static const _longueur = 6;

  final _formulaire = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();
  final _focusMotDePasse = FocusNode();

  late PasswordResetRequest? _demande = widget.args?.request;
  bool _envoi = false;
  bool _renvoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    lancerCompteARebours(widget.args?.request.resendAfterSeconds ?? 0);
    void effacer() {
      if (_erreur != null) setState(() => _erreur = null);
    }

    _code.addListener(() {
      effacer();
      // Le bouton suit le nombre de chiffres saisis.
      setState(() {});
    });
    _motDePasse.addListener(effacer);
    _confirmation.addListener(effacer);
  }

  @override
  void dispose() {
    _code.dispose();
    _motDePasse.dispose();
    _confirmation.dispose();
    _focusMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _changer() async {
    final args = widget.args;
    if (args == null || _envoi) return;
    if (_code.text.length != _longueur) {
      setState(() => _erreur = 'Saisissez les six chiffres du code reçu.');
      return;
    }
    if (!_formulaire.currentState!.validate()) return;

    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final messager = ScaffoldMessenger.of(context);
    final routeur = GoRouter.of(context);
    try {
      final identifiant = await ref
          .read(authRepositoryProvider)
          .resetPasswordWithCode(
            identifier: args.identifier,
            code: _code.text,
            newPassword: _motDePasse.text,
          );
      // Comme depuis l'écran de connexion (`route_guards.dart`) : posé avant
      // la connexion, pour gagner la course contre le routeur.
      ref.read(justLoggedInProvider.notifier).state = true;
      final connecte = await ref
          .read(authControllerProvider.notifier)
          .login(usernameOrPhone: identifiant, password: _motDePasse.text);
      if (connecte) {
        messager.showSnackBar(
          const SnackBar(
            content: Text('Mot de passe changé : vous êtes connecté.'),
          ),
        );
        return;
      }
      // Changé, mais la connexion qui suit a échoué (réseau) : le nouveau
      // mot de passe vaut, il reste à s'en servir.
      ref.read(justLoggedInProvider.notifier).state = false;
      messager.showSnackBar(
        const SnackBar(
          content: Text(
            'Mot de passe changé. Connectez-vous avec le nouveau mot de passe.',
          ),
        ),
      );
      routeur.go(AppRoutes.login);
    } on ValidationException catch (e) {
      if (!mounted) return;
      // Un code refusé se retape en entier ; un mot de passe refusé, non.
      if (e.message.toLowerCase().contains('code')) _code.clear();
      setState(() => _erreur = e.message);
    } catch (erreur) {
      if (!mounted) return;
      setState(
        () => _erreur = messagePourUtilisateur(
          erreur,
          repli: 'Le mot de passe n\'a pas pu être changé. Réessayez.',
        ),
      );
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _renvoyer() async {
    final args = widget.args;
    if (args == null) return;
    setState(() {
      _renvoi = true;
      _erreur = null;
    });
    final messager = ScaffoldMessenger.of(context);
    try {
      final nouvelle = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(args.identifier);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _demande = nouvelle;
        lancerCompteARebours(nouvelle.resendAfterSeconds);
      });
      messager.showSnackBar(
        const SnackBar(
          content: Text(
            'Si ce compte a une adresse vérifiée, un nouveau code y est parti.',
          ),
        ),
      );
    } on ValidationException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (erreur) {
      if (mounted) {
        setState(
          () => _erreur = messagePourUtilisateur(
            erreur,
            repli: 'Le code n\'a pas pu être renvoyé. Réessayez.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _renvoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demande = _demande;
    if (widget.args == null || demande == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MtcEmptyState(
          icon: Icons.lock_reset_rounded,
          title: 'Aucun code demandé',
          subtitle: 'Indiquez d\'abord votre identifiant.',
          action: TextButton(
            onPressed: () => context.go(AppRoutes.forgotPassword),
            child: const Text('Mot de passe oublié'),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau mot de passe')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formulaire,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Le serveur ne dit pas si le compte existe (`0132`) : l'écran
                // ne l'affirme pas non plus. L'identifiant, lui, est celui
                // que la personne vient de taper — rien de secret.
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Si '),
                      TextSpan(
                        text: '« ${widget.args!.identifier} »',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' correspond à un compte doté d\'une adresse '
                            'e-mail vérifiée, un code à six chiffres vient d\'y '
                            'partir. Il est valable 10 minutes.',
                      ),
                    ],
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CodeInputField(
                  controller: _code,
                  length: _longueur,
                  hasError:
                      _erreur != null &&
                      _erreur!.toLowerCase().contains('code'),
                  enabled: !_envoi,
                  // Le code complet, on passe au mot de passe.
                  onCompleted: (_) => _focusMotDePasse.requestFocus(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        secondesAvantRenvoi > 0
                            ? 'Renvoyer le code dans $delaiAvantRenvoi'
                            : 'Rien reçu ? Regardez dans les courriers '
                                  'indésirables.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          secondesAvantRenvoi == 0 && !_renvoi && !_envoi
                          ? _renvoyer
                          : null,
                      child: const Text('Renvoyer'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Nouveau mot de passe',
                  controller: _motDePasse,
                  focusNode: _focusMotDePasse,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  revealable: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Confirmer le mot de passe',
                  controller: _confirmation,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  revealable: true,
                  validator: (v) => v != _motDePasse.text
                      ? 'Les deux mots de passe ne sont pas identiques.'
                      : null,
                  textInputAction: TextInputAction.done,
                ),
                if (_erreur case final erreur?) ...[
                  const SizedBox(height: AppSpacing.md),
                  MtcErrorBanner(erreur),
                ],
                const SizedBox(height: AppSpacing.xl),
                MtcPrimaryButton(
                  label: 'Changer le mot de passe',
                  isLoading: _envoi,
                  onPressed: _envoi || _renvoi ? null : _changer,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Vos autres appareils seront déconnectés.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
