import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

/// Remplacer le mot de passe dicté par son patron, avant toute autre chose.
///
/// Un collaborateur reçoit son compte avec un code à usage unique, énoncé
/// de vive voix — parfois au téléphone, parfois dans un marché. Tant qu'il
/// n'est pas remplacé, ce compte n'est à personne : le patron le connaît,
/// et quiconque était à portée de voix aussi.
///
/// Le routeur immobilise ici : aucun onglet, aucun retour. La seule sortie
/// autre que le changement est la déconnexion.
class ForcedPasswordChangeScreen extends ConsumerStatefulWidget {
  const ForcedPasswordChangeScreen({super.key});

  @override
  ConsumerState<ForcedPasswordChangeScreen> createState() =>
      _ForcedPasswordChangeScreenState();
}

class _ForcedPasswordChangeScreenState
    extends ConsumerState<ForcedPasswordChangeScreen> {
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _nouveau.addListener(_rafraichir);
    _confirmation.addListener(_rafraichir);
  }

  void _rafraichir() => setState(() => _erreur = null);

  @override
  void dispose() {
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _peutValider =>
      _nouveau.text.length >= 6 && _nouveau.text == _confirmation.text;

  Future<void> _changer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final client = ref.read(supabaseClientProvider);
    try {
      // Le changement passe par l'authentification — seul endroit qui sache
      // hacher un mot de passe. Le drapeau se lève ensuite, et seulement
      // si le changement a réussi.
      await client.auth.updateUser(UserAttributes(password: _nouveau.text));
      await client.rpc('mark_password_changed');
      // Le profil en mémoire porte encore l'ancien drapeau : sans cette
      // relecture, le routeur renverrait aussitôt sur cet écran.
      ref.invalidate(currentUserProvider);
    } on AuthException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erreur = 'Impossible de changer le mot de passe.');
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisissez votre mot de passe'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Le code que votre responsable vous a donné ne sert qu\'une '
                'fois. Choisissez maintenant un mot de passe que vous serez '
                'seul à connaître.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              MtcTextField(
                label: 'Nouveau mot de passe (6 caractères minimum)',
                controller: _nouveau,
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.md),
              MtcTextField(
                label: 'Répétez-le',
                controller: _confirmation,
                obscureText: true,
              ),
              if (_confirmation.text.isNotEmpty &&
                  _nouveau.text != _confirmation.text)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Les deux saisies ne sont pas identiques.',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _erreur!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              MtcPrimaryButton(
                label: 'Enregistrer et continuer',
                isLoading: _enCours,
                onPressed: _peutValider ? _changer : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
