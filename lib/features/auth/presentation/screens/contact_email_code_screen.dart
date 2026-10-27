import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

/// Le code qui valide une adresse e-mail, d'après l'écran « Verification
/// code » du kit : à qui il est parti, six cases, le délai avant de pouvoir
/// en redemander un, puis « Renvoyer » et « Valider ».
///
/// L'adresse n'est enregistrée qu'ici, quand le serveur accepte le code
/// (`confirm_contact_email`, `0124`). L'écran rend `true` à celui qui l'a
/// ouvert, `false` si l'on revient changer d'adresse.
///
/// Partagé par tous les rôles, comme l'écran de l'adresse : le thème du
/// client lui vient de `ShopScope`.
class ContactEmailCodeScreen extends ConsumerStatefulWidget {
  const ContactEmailCodeScreen({super.key, required this.request});

  /// Le code déjà parti. `null` quand l'écran est ouvert sans être passé par
  /// la demande (un lien, un rechargement) : il n'y a rien à valider.
  final ContactEmailCodeRequest? request;

  @override
  ConsumerState<ContactEmailCodeScreen> createState() =>
      _ContactEmailCodeScreenState();
}

class _ContactEmailCodeScreenState
    extends ConsumerState<ContactEmailCodeScreen>
    with ResendCountdown {
  static const _longueur = 6;

  final _code = TextEditingController();
  late ContactEmailCodeRequest? _demande = widget.request;

  bool _validation = false;
  bool _renvoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    lancerCompteARebours(widget.request?.resendAfterSeconds ?? 0);
    _code.addListener(() {
      // Retaper efface le refus précédent.
      if (_erreur != null && _code.text.isNotEmpty) {
        setState(() => _erreur = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_code.text.length != _longueur || _validation) return;
    setState(() {
      _validation = true;
      _erreur = null;
    });
    try {
      await ref.read(authRepositoryProvider).confirmContactEmail(_code.text);
      ref
        ..invalidate(contactEmailStatusProvider)
        ..invalidate(contactEmailProvider);
      if (mounted) context.pop(true);
    } on ValidationException catch (e) {
      if (!mounted) return;
      // Un code refusé se retape en entier : les cases repartent vides.
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
      if (mounted) setState(() => _validation = false);
    }
  }

  Future<void> _renvoyer() async {
    final demande = _demande;
    if (demande == null) return;
    setState(() {
      _renvoi = true;
      _erreur = null;
    });
    final messager = ScaffoldMessenger.of(context);
    try {
      final nouvelle = await ref
          .read(authRepositoryProvider)
          .requestContactEmailCode(demande.email);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _demande = nouvelle;
        lancerCompteARebours(nouvelle.resendAfterSeconds);
      });
      messager.showSnackBar(
        SnackBar(content: Text('Un nouveau code est parti à ${nouvelle.email}.')),
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
    if (demande == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const MtcEmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Aucun code demandé',
          subtitle: 'Saisissez d\'abord l\'adresse e-mail à vérifier.',
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Code de vérification',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Nous avons envoyé un code à six chiffres à ',
                  ),
                  TextSpan(
                    text: demande.email,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '. Il est valable 10 minutes.'),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: _validation ? null : () => context.pop(false),
                child: const Text('Changer d\'adresse'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CodeInputField(
              controller: _code,
              length: _longueur,
              hasError: _erreur != null,
              enabled: !_validation,
              onCompleted: (_) => _valider(),
            ),
            if (_erreur case final erreur?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                erreur,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              secondesAvantRenvoi > 0
                  ? 'Renvoyer le code dans $delaiAvantRenvoi'
                  : 'Rien reçu ? Regardez dans les courriers indésirables, '
                        'ou renvoyez le code.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        secondesAvantRenvoi == 0 && !_renvoi && !_validation
                        ? _renvoyer
                        : null,
                    child: _renvoi
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Renvoyer'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MtcPrimaryButton(
                    label: 'Valider',
                    isLoading: _validation,
                    onPressed: _code.text.length == _longueur && !_renvoi
                        ? _valider
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
