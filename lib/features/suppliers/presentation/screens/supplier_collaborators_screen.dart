import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/supplier_collaborator.dart';
import '../providers/supplier_providers.dart';

/// L'équipe de la boutique.
///
/// Jusqu'ici un compte fournisseur était une personne : le patron qui
/// employait deux vendeurs n'avait qu'un choix, leur donner son mot de
/// passe. Tout ce qu'ils faisaient portait alors son nom, et le jour où
/// l'un partait, il fallait changer le mot de passe pour tout le monde.
///
/// Quatre gestes ne se délèguent jamais, et n'apparaissent donc pas dans
/// la liste des accès : demander un retrait d'argent, soumettre le dossier
/// de vérification, supprimer le compte, et gérer l'équipe elle-même.
class SupplierCollaboratorsScreen extends ConsumerWidget {
  const SupplierCollaboratorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipe = ref.watch(supplierCollaboratorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaborateurs'),
        actions: const [
          MtcHelpAction(
            title: 'Comment marchent les collaborateurs',
            message:
                'Vous créez le compte vous-même : nom, identifiant et mot de '
                'passe. Vous remettez ces deux derniers à la personne, qui se '
                'connecte avec sur son propre téléphone.\n\n'
                'Vous choisissez ce qu\'elle peut faire, et vous pouvez le '
                'changer à tout moment. Ce qui n\'est pas coché lui est '
                'refusé par le système, pas seulement caché.\n\n'
                'Quatre choses restent à vous seul, quoi qu\'il arrive : '
                'demander un retrait d\'argent, le dossier de vérification, '
                'la suppression du compte, et cette page.\n\n'
                'Retirer un collaborateur lui coupe l\'accès immédiatement. '
                'Son compte continue d\'exister : les commandes qu\'il a '
                'traitées gardent son nom.',
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncValueWidget(
          value: equipe,
          data: (liste) => liste.isEmpty
              ? const MtcEmptyState(
                  icon: Icons.group_outlined,
                  title: 'Personne pour l\'instant',
                  subtitle:
                      'Ajoutez un collaborateur pour qu\'il vous aide à tenir '
                      'la boutique, sans lui donner votre mot de passe.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: liste.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _CollaboratorCard(collaborateur: liste[index]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _NewCollaboratorSheet(),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _CollaboratorCard extends ConsumerWidget {
  const _CollaboratorCard({required this.collaborateur});

  final SupplierCollaborator collaborateur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accordes = CollaboratorPermission.values
        .where((p) => collaborateur.permissions.contains(p.code))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collaborateur.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Se connecte avec « ${collaborateur.usernameOrPhone} »',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            // Tant que le code dicté n'a pas été remplacé, quiconque l'a
            // entendu peut ouvrir ce compte. Le dire ici, pas ailleurs :
            // c'est le seul endroit où le patron regarde son équipe.
            if (collaborateur.mustChangePassword)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.key_outlined, size: 16, color: scheme.tertiary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'N\'a pas encore choisi son mot de passe',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (accordes.isEmpty)
              Text(
                'Aucun accès accordé — ce compte ne peut rien faire pour '
                'l\'instant.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final permission in accordes)
                    Chip(
                      label: Text(permission.label),
                      backgroundColor: scheme.secondaryContainer,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) =>
                        _PermissionsSheet(collaborateur: collaborateur),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Accès'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmerRetrait(context, ref),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Retirer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerRetrait(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Retirer ${collaborateur.displayName} ?'),
        content: const Text(
          'Son accès à la boutique est coupé immédiatement. Son compte '
          'continue d\'exister, et les commandes qu\'il a traitées gardent '
          'son nom.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await ref
        .read(supplierCollaboratorControllerProvider.notifier)
        .remove(collaborateur.userId);
  }
}

/// Les cases à cocher, partagées par la création et la modification.
class _PermissionsPicker extends StatelessWidget {
  const _PermissionsPicker({required this.choisies, required this.onChanged});

  final Set<String> choisies;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final permission in CollaboratorPermission.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(permission.label),
            subtitle: Text(permission.description),
            value: choisies.contains(permission.code),
            onChanged: (coche) {
              final suivantes = {...choisies};
              if (coche == true) {
                suivantes.add(permission.code);
              } else {
                suivantes.remove(permission.code);
              }
              onChanged(suivantes);
            },
          ),
      ],
    );
  }
}

class _PermissionsSheet extends ConsumerStatefulWidget {
  const _PermissionsSheet({required this.collaborateur});

  final SupplierCollaborator collaborateur;

  @override
  ConsumerState<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends ConsumerState<_PermissionsSheet> {
  late Set<String> _choisies = {...widget.collaborateur.permissions};

  @override
  Widget build(BuildContext context) {
    final enCours = ref
        .watch(supplierCollaboratorControllerProvider)
        .isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Accès de ${widget.collaborateur.displayName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _PermissionsPicker(
              choisies: _choisies,
              onChanged: (suivantes) => setState(() => _choisies = suivantes),
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcPrimaryButton(
              label: 'Enregistrer',
              isLoading: enCours,
              onPressed: () async {
                final ok = await ref
                    .read(supplierCollaboratorControllerProvider.notifier)
                    .setPermissions(
                      userId: widget.collaborateur.userId,
                      permissions: _choisies,
                    );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Accès mis à jour.' : 'Une erreur est survenue',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCollaboratorSheet extends ConsumerStatefulWidget {
  const _NewCollaboratorSheet();

  @override
  ConsumerState<_NewCollaboratorSheet> createState() =>
      _NewCollaboratorSheetState();
}

class _NewCollaboratorSheetState
    extends ConsumerState<_NewCollaboratorSheet> {
  final _nom = TextEditingController();
  final _identifiant = TextEditingController();
  final _telephone = TextEditingController();
  Set<String> _choisies = {};

  @override
  void initState() {
    super.initState();
    _nom.addListener(_rafraichir);
    _identifiant.addListener(_rafraichir);
  }

  void _rafraichir() => setState(() {});

  @override
  void dispose() {
    _nom.dispose();
    _identifiant.dispose();
    _telephone.dispose();
    super.dispose();
  }

  /// Mêmes bornes que la fonction edge, qui refuserait de toute façon.
  /// Les poser ici évite d'envoyer une requête pour s'entendre dire non.
  bool get _peutCreer =>
      _nom.text.trim().length >= 2 &&
      _identifiant.text.trim().length >= 3 &&
      !_identifiant.text.trim().contains(' ');

  @override
  Widget build(BuildContext context) {
    final enCours = ref
        .watch(supplierCollaboratorControllerProvider)
        .isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nouveau collaborateur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vous créez son compte. Un mot de passe provisoire vous sera '
              'donné à la fin : dictez-le-lui, il devra le remplacer à sa '
              'première connexion.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(label: 'Nom complet', controller: _nom),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Identifiant de connexion (sans espace)',
              controller: _identifiant,
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Téléphone (optionnel)',
              controller: _telephone,
              keyboardType: TextInputType.phone,
            ),
            const Divider(height: AppSpacing.xl),
            Text(
              'Que peut-il faire ?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _PermissionsPicker(
              choisies: _choisies,
              onChanged: (suivantes) => setState(() => _choisies = suivantes),
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcPrimaryButton(
              label: 'Créer le compte',
              isLoading: enCours,
              onPressed: _peutCreer ? _creer : null,
            ),
            TextButton(
              onPressed: enCours ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _creer() async {
    final controller = ref.read(
      supplierCollaboratorControllerProvider.notifier,
    );
    final motDePasse = await controller.create(
      displayName: _nom.text.trim(),
      usernameOrPhone: _identifiant.text.trim(),
      phoneNumber: _telephone.text.trim(),
      permissions: _choisies,
    );
    if (!mounted) return;
    if (motDePasse != null) {
      Navigator.of(context).pop();
      await _montrerMotDePasse(context, motDePasse);
      return;
    }
    // Le motif vient du serveur — nom déjà pris, mot de passe trop court.
    // On l'affiche tel quel plutôt que d'en inventer un moins précis.
    final erreur = ref.read(supplierCollaboratorControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erreur.toString().replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }
}

/// Montre le mot de passe provisoire, une fois.
///
/// En boîte de dialogue et non en bandeau fugace : il doit être lu, parfois
/// recopié sur un papier, souvent dicté au téléphone. Un message qui
/// s'efface au bout de quatre secondes obligerait à recréer le compte.
///
/// Il n'est stocké nulle part en clair et ne se relit pas. Si le patron le
/// perd, il peut en faire engendrer un nouveau depuis la fiche du
/// collaborateur.
Future<void> _montrerMotDePasse(BuildContext context, String motDePasse) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Compte créé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dictez ce mot de passe provisoire à la personne :'),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            motDePasse,
            style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Il ne s\'affichera plus. Elle devra le remplacer dès sa '
            'première connexion.',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('J\'ai noté'),
        ),
      ],
    ),
  );
}
