import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/promotion.dart';
import '../../domain/entities/promotion_batch.dart';
import '../controllers/supplier_promotion_controller.dart';
import '../providers/supplier_product_providers.dart';
import '../widgets/product_multi_picker.dart';

/// Les remises du fournisseur, pensées comme il les pense.
///
/// La feuille ouverte depuis un produit (`supplier_promotions_sheet.dart`)
/// reste le bon geste quand on travaille **sur** un article. Elle est le
/// mauvais geste quand la décision porte sur un ensemble : « -20 % sur tout
/// le bogolan » y demandait d'ouvrir chaque article, de ressaisir les mêmes
/// valeurs, et d'y revenir un par un pour arrêter la remise. Au-delà de
/// quelques produits, personne ne le fait — la remise reste en vigueur bien
/// après la date prévue.
///
/// Ici, on décrit la remise d'abord, on choisit les produits ensuite.
class SupplierPromotionsScreen extends ConsumerWidget {
  const SupplierPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(myPromotionBatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remises'),
        actions: const [
          MtcHelpAction(
            title: 'Comment marchent les remises',
            message:
                'Une remise s\'applique automatiquement : le client voit le '
                'prix remisé sans rien saisir. C\'est la différence avec un '
                'code promo, qu\'il faut taper.\n\n'
                'Quand plusieurs remises touchent un même produit, le client '
                'paie la plus avantageuse — elles ne s\'additionnent pas. '
                'Une remise automatique l\'emporte aussi sur un code promo '
                'moins avantageux.\n\n'
                'Une remise créée ici couvre plusieurs produits à la fois : '
                'l\'arrêter ou la supprimer vaut pour tous d\'un seul geste.',
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncValueWidget(
          value: batches,
          data: (list) => list.isEmpty
              ? const MtcEmptyState(
                  icon: Icons.sell_outlined,
                  title: 'Aucune remise',
                  subtitle:
                      'Créez une remise, puis choisissez les produits '
                      'qu\'elle couvre.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _BatchCard(
                    batch: list[index],
                    onEdit: () => _openForm(context, existing: list[index]),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle remise'),
      ),
    );
  }

  /// Le formulaire s'ouvre en feuille, et n'existe pas tant qu'on ne l'a pas
  /// demandé. Une version précédente de l'écran des codes promo affichait
  /// un formulaire permanent sous la liste : on ne savait plus s'il créait
  /// ou s'il modifiait, et il a fini par créer deux entrées d'un coup.
  void _openForm(BuildContext context, {PromotionBatch? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _BatchSheet(existing: existing),
    );
  }
}

class _BatchCard extends ConsumerWidget {
  const _BatchCard({required this.batch, required this.onEdit});

  final PromotionBatch batch;

  /// Rouvre la remise dans le formulaire, déjà remplie. Seules les remises
  /// en lot sont modifiables ici : une remise posée depuis la fiche d'un
  /// produit se corrige là-bas, où elle est née.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final running = batch.isRunningAt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    batch.label?.isNotEmpty == true
                        ? batch.label!
                        : _amountLabel(batch),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // La pastille ne répète pas le titre : sans intitulé, le
                // titre **est** le montant, et l'afficher deux fois côte à
                // côte donne l'impression d'un doublon d'affichage.
                if (batch.label?.isNotEmpty == true)
                  Chip(
                    label: Text(_amountLabel(batch)),
                    backgroundColor: running
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _coverage(batch),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (batch.minQuantity > 1)
              Text(
                'À partir de ${batch.minQuantity} unités',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              _window(batch),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: running ? scheme.primary : scheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // `Wrap` et non `Row` : trois boutons à icône et libellé ne
            // tiennent pas sur la largeur d'un téléphone — le parcours
            // visuel l'a montré par un débordement de 4,8 pixels. Ils
            // passent à la ligne au lieu de se faire couper.
            if (batch.isGrouped)
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                  TextButton.icon(
                    onPressed: () => ref
                        .read(supplierPromotionControllerProvider.notifier)
                        .setBatchActive(
                          batchId: batch.batchId!,
                          isActive: !batch.isActive,
                        ),
                    icon: Icon(
                      batch.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(batch.isActive ? 'Arrêter' : 'Reprendre'),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref, batch),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ],
              )
            else
              Text(
                'Posée depuis la fiche du produit — gérez-la là-bas.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PromotionBatch batch,
  ) async {
    // Supprimer touche autant de lignes qu'il y a de produits : le dire
    // avant, puisque le bouton ne le montre pas.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette remise ?'),
        content: Text(
          'Elle sera retirée de ${batch.productCount} produit'
          '${batch.productCount > 1 ? 's' : ''}. Les prix reviennent '
          'immédiatement au plein tarif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(supplierPromotionControllerProvider.notifier)
        .removeBatch(batch.batchId!);
  }

  static String _amountLabel(PromotionBatch batch) => switch (batch.kind) {
    PromotionKind.percentage => '-${batch.value}%',
    PromotionKind.fixedAmount =>
      '-${CurrencyFormatter.formatFcfa(batch.value)}',
  };

  static String _coverage(PromotionBatch batch) {
    final names = batch.productNames.take(3).join(', ');
    final reste = batch.productCount - 3;
    return reste > 0
        ? '${batch.productCount} produits : $names, et $reste autre'
              '${reste > 1 ? 's' : ''}'
        : '${batch.productCount} produit'
              '${batch.productCount > 1 ? 's' : ''} : $names';
  }

  static String _window(PromotionBatch batch) {
    if (!batch.isActive) return 'Arrêtée';
    final debut = batch.startsAt;
    final fin = batch.endsAt;
    if (debut == null && fin == null) return 'En cours, sans date de fin';
    if (fin == null) return 'À partir du ${DateFormatter.formatDate(debut!)}';
    if (debut == null) return 'Jusqu\'au ${DateFormatter.formatDate(fin)}';
    return 'Du ${DateFormatter.formatDate(debut)} au '
        '${DateFormatter.formatDate(fin)}';
  }
}

class _BatchSheet extends ConsumerStatefulWidget {
  const _BatchSheet({this.existing});

  /// `null` pour une création. Sinon, la remise à corriger : le formulaire
  /// s'ouvre rempli, couverture comprise.
  final PromotionBatch? existing;

  @override
  ConsumerState<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends ConsumerState<_BatchSheet> {
  late PromotionKind _kind;
  late final TextEditingController _valueController;
  late final TextEditingController _minQuantityController;
  late final TextEditingController _labelController;
  DateTime? _startsAt;
  DateTime? _endsAt;
  late Set<String> _productIds;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? PromotionKind.percentage;
    _valueController = TextEditingController(
      text: '${existing?.value ?? 10}',
    );
    _minQuantityController = TextEditingController(
      text: '${existing?.minQuantity ?? 1}',
    );
    _labelController = TextEditingController(text: existing?.label ?? '');
    _startsAt = existing?.startsAt;
    _endsAt = existing?.endsAt;
    _productIds = {...?existing?.productIds};
    _valueController.addListener(_refresh);
    _minQuantityController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _valueController
      ..removeListener(_refresh)
      ..dispose();
    _minQuantityController
      ..removeListener(_refresh)
      ..dispose();
    _labelController.dispose();
    super.dispose();
  }

  /// La valeur saisie, ou `null` si elle n'est pas utilisable. Mêmes bornes
  /// que la base (`0062`) : un pourcentage au-delà de 90 y est refusé, et
  /// découvrir le refus après avoir choisi trente produits serait pénible.
  int? get _value {
    final value = int.tryParse(_valueController.text.trim());
    if (value == null || value <= 0) return null;
    if (_kind == PromotionKind.percentage && value > 90) return null;
    return value;
  }

  bool get _canSubmit => _value != null && _productIds.isNotEmpty;

  Future<void> _submit() async {
    final controller = ref.read(supplierPromotionControllerProvider.notifier);
    final minQuantity = int.tryParse(_minQuantityController.text.trim()) ?? 1;
    final label = _labelController.text.trim().isEmpty
        ? null
        : _labelController.text.trim();

    final ok = _isEditing
        ? await controller.updateBatch(
            batchId: widget.existing!.batchId!,
            productIds: _productIds.toList(),
            kind: _kind,
            value: _value!,
            minQuantity: minQuantity,
            startsAt: _startsAt,
            endsAt: _endsAt,
            label: label,
          )
        : await controller.createBatch(
            productIds: _productIds.toList(),
            kind: _kind,
            value: _value!,
            minQuantity: minQuantity,
            startsAt: _startsAt,
            endsAt: _endsAt,
            label: label,
          );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'Une erreur est survenue'
              : _isEditing
              ? 'Remise mise à jour : ${_productIds.length} produit'
                    '${_productIds.length > 1 ? 's' : ''}.'
              : 'Remise posée sur ${_productIds.length} produit'
                    '${_productIds.length > 1 ? 's' : ''}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    final isLoading = ref.watch(supplierPromotionControllerProvider).isLoading;
    final products = supplierId == null
        ? const []
        : ref.watch(myProductsProvider(supplierId)).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Modifier la remise' : 'Nouvelle remise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<PromotionKind>(
              segments: const [
                ButtonSegment(
                  value: PromotionKind.percentage,
                  label: Text('Pourcentage'),
                ),
                ButtonSegment(
                  value: PromotionKind.fixedAmount,
                  label: Text('Montant'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: _kind == PromotionKind.percentage
                  ? 'Remise en % (1 à 90)'
                  : 'Remise en FCFA',
              controller: _valueController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'À partir de combien d\'unités (1 = dès le premier)',
              controller: _minQuantityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Intitulé (optionnel, ex. « Soldes de saison »)',
              controller: _labelController,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: Text(
                      _startsAt == null
                          ? 'Début : tout de suite'
                          : 'Dès le ${DateFormatter.formatDate(_startsAt!)}',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: Text(
                      _endsAt == null
                          ? 'Fin : aucune'
                          : 'Jusqu\'au ${DateFormatter.formatDate(_endsAt!)}',
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            Text(
              'Sur quels produits ?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            // `emptyMeansAll: false` : contrairement à un code promo, ne
            // rien choisir ici ne veut pas dire « tous ». Une remise sans
            // produit ne s'applique nulle part, et le bouton reste donc
            // inactif tant qu'on n'en a pas désigné au moins un.
            ProductMultiPicker(
              products: products.cast(),
              selected: _productIds,
              emptyMeansAll: false,
              onChanged: (ids) => setState(() => _productIds = ids),
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcPrimaryButton(
              label: _isEditing ? 'Enregistrer' : 'Poser la remise',
              isLoading: isLoading,
              onPressed: _canSubmit ? _submit : null,
            ),
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startsAt : _endsAt) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        // Fin de journée : une remise « jusqu'au 15 » doit couvrir le 15.
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }
}
