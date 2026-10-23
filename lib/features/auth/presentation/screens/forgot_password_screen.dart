import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/auth_providers.dart';

/// Mot de passe oublié, première étape : désigner son compte (`0127`).
///
/// Par l'identifiant de connexion, ou par l'adresse e-mail vérifiée du
/// compte — on oublie aussi son identifiant, et l'e-mail du code le
/// rappelle. Le code part à cette adresse : un compte sans adresse vérifiée
/// ne se récupère pas ainsi, et l'écran le dit avant qu'on essaie.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.identifier});

  /// Ce qui était déjà tapé sur l'écran de connexion.
  final String? identifier;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formulaire = GlobalKey<FormState>();
  late final _champ = TextEditingController(text: widget.identifier ?? '');
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _champ.addListener(() {
      if (_erreur != null) setState(() => _erreur = null);
    });
  }

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_formulaire.currentState!.validate()) return;
    final identifiant = _champ.text.trim();
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final demande = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(identifiant);
      if (!mounted) return;
      await context.push(
        AppRoutes.forgotPasswordCode,
        extra: (identifier: identifiant, request: demande),
      );
    } on ValidationException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (erreur) {
      if (mounted) {
        setState(
          () => _erreur = messagePourUtilisateur(
            erreur,
            repli: 'Le code n\'a pas pu être envoyé. Réessayez.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formulaire,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Récupérer votre compte',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Saisissez votre identifiant de connexion, ou l\'adresse '
                  'e-mail vérifiée de votre compte. Un code y sera envoyé pour '
                  'choisir un nouveau mot de passe.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                MtcTextField(
                  label: 'Identifiant ou adresse e-mail',
                  controller: _champ,
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Saisissez votre identifiant ou votre adresse e-mail.'
                      : null,
                ),
                if (_erreur case final erreur?) ...[
                  const SizedBox(height: AppSpacing.md),
                  MtcErrorBanner(erreur),
                ],
                const SizedBox(height: AppSpacing.xl),
                MtcPrimaryButton(
                  label: 'Recevoir un code',
                  isLoading: _enCours,
                  onPressed: _enCours ? null : _envoyer,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Dit avant qu'on essaie : sans adresse vérifiée, le code
                // n'a nulle part où aller.
                Text(
                  'Le code ne part qu\'à une adresse e-mail vérifiée. Sans '
                  'elle, seule l\'équipe MTC peut vous aider à retrouver votre '
                  'compte.',
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
