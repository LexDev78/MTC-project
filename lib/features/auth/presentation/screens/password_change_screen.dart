import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/app_user.dart';
import '../providers/auth_providers.dart';

/// Changer son mot de passe, de son plein gré.
///
/// Pendant de `ForcedPasswordChangeScreen`, qui sert au premier passage d'un
/// collaborateur et n'a pas à demander l'ancien mot de passe (son patron le
/// lui a dicté, il vient de s'en servir). Ici, au contraire, on le demande :
/// sans lui, quiconque trouve un téléphone déverrouillé, session ouverte,
/// pourrait confisquer le compte en une minute.
///
/// Ouvert à tous les rôles, sous `/compte/…` : client, fournisseur,
/// collaborateur et livreur gèrent chacun le leur.
class PasswordChangeScreen extends ConsumerStatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  ConsumerState<PasswordChangeScreen> createState() =>
      _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends ConsumerState<PasswordChangeScreen> {
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  /// 10 caractères pour un compte du staff MTC, qui voit les commandes, les
  /// pièces d'identité et les versements (`0135`) ; 6 pour les autres, le
  /// minimum de Supabase Auth. La règle du staff vaut aussi pour le mot de
  /// passe oublié (`reset_password_with_code`, `0132`).
  int get _longueurMinimale =>
      ref.read(currentUserProvider).valueOrNull is SupplierPrincipalUser
      ? 10
      : 6;

  @override
  void initState() {
    super.initState();
    for (final champ in [_actuel, _nouveau, _confirmation]) {
      // Retaper efface l'erreur précédente : un message qui reste affiché
      // pendant qu'on corrige fait croire que la correction ne marche pas.
      champ.addListener(() => setState(() => _erreur = null));
    }
  }

  @override
  void dispose() {
    _actuel.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _confirmationDiffere =>
      _confirmation.text.isNotEmpty && _nouveau.text != _confirmation.text;

  bool get _peutValider =>
      _actuel.text.isNotEmpty &&
      _nouveau.text.length >= _longueurMinimale &&
      _nouveau.text == _confirmation.text;

  Future<void> _changer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _actuel.text,
            newPassword: _nouveau.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe changé.')),
      );
      context.pop();
    } on ValidationException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erreur =
              'Impossible de changer le mot de passe pour le moment. Réessayez.',
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
      appBar: AppBar(title: const Text('Mot de passe')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Changer votre mot de passe',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Saisissez d\'abord celui que vous utilisez aujourd\'hui : il '
              'prouve que c\'est bien vous.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcTextField(
              label: 'Mot de passe actuel',
              controller: _actuel,
              obscureText: true,
              revealable: true,
              prefixIcon: Icons.lock_outline_rounded,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcTextField(
              label: 'Nouveau mot de passe',
              controller: _nouveau,
              obscureText: true,
              revealable: true,
              prefixIcon: Icons.lock_reset_rounded,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.xs),
            // La règle est dite avant l'erreur, pas seulement après : on
            // n'apprend pas qu'il faut six caractères en se faisant refuser.
            _Regle(
              respectee: _nouveau.text.length >= _longueurMinimale,
              texte: '$_longueurMinimale caractères minimum',
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Confirmer le nouveau mot de passe',
              controller: _confirmation,
              obscureText: true,
              revealable: true,
              prefixIcon: Icons.lock_reset_rounded,
              textInputAction: TextInputAction.done,
            ),
            if (_confirmationDiffere)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Les deux saisies ne sont pas identiques.',
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            if (_erreur case final erreur?) ...[
              const SizedBox(height: AppSpacing.md),
              MtcErrorBanner(erreur),
            ],
            const SizedBox(height: AppSpacing.xl),
            MtcPrimaryButton(
              label: 'Changer le mot de passe',
              isLoading: _enCours,
              onPressed: _peutValider && !_enCours ? _changer : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Une règle de saisie, cochée quand elle est respectée.
class _Regle extends StatelessWidget {
  const _Regle({required this.respectee, required this.texte});

  final bool respectee;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final couleur = respectee ? scheme.primary : scheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          respectee ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: couleur,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          texte,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: couleur),
        ),
      ],
    );
  }
}
