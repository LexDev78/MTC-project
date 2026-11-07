import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/auth_providers.dart';

/// Ajouter, changer ou retirer son adresse e-mail.
///
/// L'adresse est **facultative** et ne remplace pas l'identifiant de
/// connexion. L'écran le dit d'emblée, parce que c'est la première question
/// qu'on se pose en voyant un champ e-mail dans une app où l'on ne s'est
/// jamais connecté par e-mail.
///
/// Une adresse ne s'enregistre qu'une fois vérifiée (`0124`) : « Recevoir un
/// code » envoie six chiffres à l'adresse saisie, et c'est sur l'écran du
/// code (`ContactEmailCodeScreen`) qu'elle devient celle du compte. Une
/// adresse enregistrée avant cette règle est montrée « non vérifiée », avec
/// de quoi la vérifier.
class ContactEmailScreen extends ConsumerWidget {
  const ContactEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adresse e-mail')),
      body: AsyncValueWidget(
        value: ref.watch(contactEmailStatusProvider),
        data: (etat) =>
            _Formulaire(actuelle: etat.email, verifiee: etat.verified),
      ),
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.actuelle, required this.verifiee});

  final String? actuelle;
  final bool verifiee;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  late final _champ = TextEditingController(text: widget.actuelle ?? '');
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _champ.addListener(() => setState(() => _erreur = null));
  }

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  /// Le contrôle côté écran n'est qu'une politesse : il évite d'envoyer une
  /// saisie manifestement incomplète. C'est le serveur qui tranche
  /// (`request_contact_email_code`), y compris pour les doublons.
  bool get _semblableAUneAdresse {
    final texte = _champ.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texte);
  }

  bool get _inchangee =>
      _champ.text.trim().toLowerCase() == (widget.actuelle ?? '');

  /// Envoie le code, ouvre l'écran où on le donne, et revient avec la
  /// réponse : enregistrée, ou l'on veut changer d'adresse.
  Future<void> _verifier(String adresse) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final demande = await ref
          .read(authRepositoryProvider)
          .requestContactEmailCode(adresse);
      if (!mounted) return;
      setState(() => _enCours = false);
      final verifiee = await context.push<bool>(
        AppRoutes.accountEmailCode,
        extra: demande,
      );
      if (verifiee != true || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adresse vérifiée et enregistrée : ${demande.email}'),
        ),
      );
      context.pop();
    } on ValidationException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erreur =
              'Le code n\'a pas pu être envoyé pour le moment. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _retirer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer votre adresse e-mail ?'),
        content: const Text(
          'Vous continuerez à vous connecter avec votre identifiant. Vous '
          'pourrez en ajouter une autre à tout moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await ref.read(authRepositoryProvider).setContactEmail(null);
      ref
        ..invalidate(contactEmailStatusProvider)
        ..invalidate(contactEmailProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse e-mail retirée.')),
      );
      context.pop();
    } on ValidationException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erreur =
              'Impossible de retirer l\'adresse pour le moment. Réessayez.',
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
    final actuelle = widget.actuelle;
    // La même adresse se revérifie tant qu'elle ne l'a jamais été ; une
    // autre se vérifie toujours.
    final aVerifier = _inchangee ? !widget.verifiee : true;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            actuelle != null
                ? 'Votre adresse e-mail'
                : 'Ajouter une adresse e-mail',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Facultative. Elle permet de vous joindre, et servira à récupérer '
            'votre compte si vous oubliez votre mot de passe. Un code à six '
            'chiffres vous est envoyé pour la vérifier.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (actuelle != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Etat(adresse: actuelle, verifiee: widget.verifiee),
          ],
          const SizedBox(height: AppSpacing.md),
          // Ce qui ne change pas, dit à l'endroit où l'on pourrait s'en
          // inquiéter.
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Vous continuez à vous connecter avec votre identifiant '
                    'habituel.',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          MtcTextField(
            label: 'Adresse e-mail',
            controller: _champ,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
          ),
          if (_erreur case final erreur?) ...[
            const SizedBox(height: AppSpacing.md),
            MtcErrorBanner(erreur),
          ],
          const SizedBox(height: AppSpacing.xl),
          MtcPrimaryButton(
            label: _inchangee && actuelle != null && !widget.verifiee
                ? 'Vérifier cette adresse'
                : 'Recevoir un code',
            isLoading: _enCours,
            onPressed: _semblableAUneAdresse && aVerifier && !_enCours
                ? () => _verifier(_champ.text.trim())
                : null,
          ),
          if (actuelle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _enCours ? null : _retirer,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Retirer cette adresse'),
            ),
          ],
        ],
      ),
    );
  }
}

/// L'adresse enregistrée et son état, en un coup d'œil.
class _Etat extends StatelessWidget {
  const _Etat({required this.adresse, required this.verifiee});

  final String adresse;
  final bool verifiee;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // La couleur de la marque pour « vérifiée » : un vert choisi à la main
    // n'aurait pas de variante sombre.
    final couleur = verifiee ? scheme.primary : scheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          verifiee ? Icons.verified_rounded : Icons.error_outline_rounded,
          size: 20,
          color: couleur,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: adresse,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: verifiee
                      ? ' · vérifiée'
                      : ' · jamais vérifiée : vérifiez-la pour qu\'elle '
                            'serve à récupérer votre compte.',
                  style: TextStyle(color: couleur),
                ),
              ],
            ),
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
