import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/supplier_product_controller.dart';
import '../providers/catalog_providers.dart';
import '../../domain/entities/promotion.dart';
import '../widgets/promotion_badge.dart';
import 'supplier_promotions_sheet.dart';
import 'supplier_variant_manager_screen.dart';

/// Create/edit form, reached from `SupplierProductListScreen` — `product`
/// null means create mode. On edit, stock isn't overwritten directly:
/// the difference between the field's new value and the loaded product's
/// current stock is applied through `ProductRepository.adjustStock`, so the
/// stock-movement log stays accurate no matter which screen a correction
/// came from (this form or `SupplierStockAdjustSheet`).
class SupplierProductFormScreen extends ConsumerStatefulWidget {
  const SupplierProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<SupplierProductFormScreen> createState() =>
      _SupplierProductFormScreenState();
}

class _SupplierProductFormScreenState
    extends ConsumerState<SupplierProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.product?.name);
  late final _descriptionController = TextEditingController(
    text: widget.product?.description,
  );
  late final _priceController = TextEditingController(
    text: widget.product?.priceFcfa.toString(),
  );
  late final _compareAtPriceController = TextEditingController(
    text: widget.product?.compareAtPriceFcfa?.toString(),
  );
  late final _stockController = TextEditingController(
    text: (widget.product?.stockQuantity ?? 0).toString(),
  );
  late final _lowStockThresholdController = TextEditingController(
    text: widget.product?.lowStockThreshold?.toString(),
  );
  late final _weightController = TextEditingController(
    text: widget.product?.weightKg.toString(),
  );
  late final _cityController = TextEditingController(text: widget.product?.city);

  late ProductCategory _category =
      widget.product?.category ?? ProductCategory.autre;
  late ProductRegion _region = widget.product?.region ?? ProductRegion.mali;
  late bool _allowsSelfDelivery = widget.product?.allowsSelfDelivery ?? true;
  late bool _allowsMtcDelivery = widget.product?.allowsMtcDelivery ?? true;
  late ProductStatus _status = widget.product?.status ?? ProductStatus.draft;

  /// Starts as `widget.product` (whatever the caller had on hand — often the
  /// supplier's product list stream, which does NOT embed
  /// `characteristics`/`variants`, only the scalar aggregate columns) so the
  /// price/stock/name fields above render instantly, then gets replaced by a
  /// `getById` fetch (which DOES embed them) as soon as this screen opens in
  /// edit mode — see [_loadFreshProduct]. [_variantPanelGeneration] tracks
  /// how many such fetches have completed; the "Caractéristiques et
  /// variantes" section waits for the first one before ever constructing
  /// [VariantManagerPanel], and gets a fresh `key` on every one after that
  /// (including post-save), so the panel's in-memory draft is always reseeded
  /// from confirmed database truth rather than silently carrying over
  /// whatever was in memory from before — that mismatch is exactly what
  /// caused previously-saved variants to disappear (and then get wiped by
  /// `saveCharacteristicsAndVariants`'s full-replace) when a supplier left
  /// and re-entered this screen.
  Product? _currentProduct;
  int _variantPanelGeneration = 0;

  /// Re-created every time [_variantPanelGeneration] bumps, alongside the
  /// panel's own fresh `key` below — gives `_submit` a handle onto whichever
  /// panel instance is actually on screen right now, to pull its draft via
  /// `VariantManagerPanelState.buildDraft` when saving.
  var _variantPanelKey = GlobalKey<VariantManagerPanelState>();

  /// Vrai tant que le panneau compose une variante. Le bouton de validation
  /// du formulaire s'efface alors : deux actions principales empilées dans
  /// la même colonne (« Ajouter cette variante » puis « Enregistrer »)
  /// donnaient un écran surchargé où rien n'indiquait laquelle termine quoi
  /// — et « Enregistrer » à ce moment-là perd la variante en cours sans le
  /// dire, puisque `buildDraft` ne lit que les variantes déjà confirmées.
  var _isComposingVariant = false;

  bool get _isEditing => widget.product != null;
  bool get _hasVariants => _currentProduct?.hasVariants ?? false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    if (_isEditing) {
      _loadFreshProduct();
    }
  }

  Future<void> _loadFreshProduct() async {
    final fresh = await ref.read(productRepositoryProvider).getById(widget.product!.id);
    if (!mounted) return;
    setState(() {
      _currentProduct = fresh;
      _variantPanelGeneration++;
      _variantPanelKey = GlobalKey();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    _weightController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  int? _parseOptionalInt(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Read from the panel's live draft, not `_hasVariants` (which only
    // reflects what's already in the database) — a supplier composing
    // variants for the very first time and flipping to "Actif" in this same
    // save hasn't saved anything yet, so `_currentProduct.hasVariants` would
    // still read `false` at this point even though the save about to happen
    // will give it variants.
    final variantDraft = _isEditing ? _variantPanelKey.currentState?.buildDraft() : null;
    final willHaveVariants = variantDraft?.variants.isNotEmpty ?? _hasVariants;

    // Backed by `products_active_requires_variants`
    // (`0021_backfill_default_variants_and_require_variant.sql`) — caught
    // here too so the supplier gets a clear message instead of a raw
    // Postgres exception from the deferred constraint trigger.
    if (_status == ProductStatus.active && !willHaveVariants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ajoutez au moins une caractéristique et une variante avant de '
            'passer ce produit en statut "Actif".',
          ),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final priceFcfa = int.parse(_priceController.text.trim());
    final compareAtPriceFcfa = _parseOptionalInt(
      _compareAtPriceController.text,
    );
    final stockQuantity = int.parse(_stockController.text.trim());
    final lowStockThreshold = _parseOptionalInt(
      _lowStockThresholdController.text,
    );
    final weightKg = double.parse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    final city = _cityController.text.trim();

    final controller = ref.read(supplierProductControllerProvider.notifier);
    bool success;

    if (_isEditing) {
      var original = widget.product!;

      // Variants before the product's own fields: flipping `status` to
      // `active` in this same submit needs `has_variants` to already be
      // true by the time that update runs, or
      // `products_active_requires_variants` rejects it — see the guard
      // above for the client-side version of that same check.
      success = variantDraft == null
          ? true
          : await controller.saveCharacteristicsAndVariants(
              productId: original.id,
              characteristics: variantDraft.characteristics,
              variants: variantDraft.variants,
            );

      // Once variants exist, `price_fcfa`/`stock_quantity`/`image_urls` on
      // `products` are trigger-maintained aggregates
      // (`product_variants_aggregate_products`, `0018_product_variants.sql`)
      // that the save above just recomputed — `original` is whatever the
      // caller had *before* this whole edit session (see this class's doc
      // comment; `_loadFreshProduct` only ever refreshes `_currentProduct`,
      // a separate reference). Basing the update below directly on it would
      // silently revert what the trigger just set — concretely, this is
      // what made a supplier's first variant photo (and its price/stock)
      // vanish immediately after saving.
      if (success && willHaveVariants) {
        original = await ref.read(productRepositoryProvider).getById(original.id);
      }

      if (success) {
        success = await controller.updateProduct(
          // `sizes`/`colors` aren't editable from this form anymore (see
          // `_submit`'s call site removal) — carried over unchanged rather
          // than cleared, since old products may still have values in them
          // and clearing on every save would silently wipe that data.
          // `imageUrls`/`stockQuantity` are likewise carried over from
          // `original` unchanged (not listed below) — correct here since,
          // by this point, `original` is the fresh aggregate whenever
          // variants are involved, and the plain product-level fields
          // otherwise.
          original.copyWith(
            name: name,
            description: description,
            category: _category,
            priceFcfa: willHaveVariants ? original.priceFcfa : priceFcfa,
            compareAtPriceFcfa: compareAtPriceFcfa,
            weightKg: weightKg,
            city: city,
            allowsSelfDelivery: _allowsSelfDelivery,
            allowsMtcDelivery: _allowsMtcDelivery,
            region: _region,
            lowStockThreshold: lowStockThreshold,
            status: _status,
          ),
        );
      }
      // Only meaningful for a still variant-less product: once
      // `willHaveVariants` is true (already was, or just became true above),
      // stock is scoped per-variant — `adjust_stock` itself refuses a
      // product-level (`variantId: null`) delta once `has_variants` is set,
      // and the field driving `stockQuantity` is only ever shown editable
      // (rather than the read-only variants aggregate) while that's false.
      final stockDelta = stockQuantity - original.stockQuantity;
      if (success && !willHaveVariants && stockDelta != 0) {
        success = await controller.adjustStock(
          productId: original.id,
          quantityDelta: stockDelta,
          reason: StockMovementReason.manualAdjustment,
          note: 'Modifié depuis la fiche produit',
        );
      }
    } else {
      success = await controller.createProduct(
        name: name,
        description: description,
        category: _category,
        priceFcfa: priceFcfa,
        stockQuantity: stockQuantity,
        weightKg: weightKg,
        city: city,
        // No product-level photo picker anymore — a product with variants
        // gets its photo from the default variant automatically
        // (`product_variants_aggregate_products` trigger,
        // `0018_product_variants.sql`), and one without variants can't
        // reach `active` at all (`products_active_requires_variants`,
        // `0021_backfill_default_variants_and_require_variant.sql`).
        imageUrls: const [],
        allowsSelfDelivery: _allowsSelfDelivery,
        allowsMtcDelivery: _allowsMtcDelivery,
        sizes: const [],
        colors: const [],
        region: _region,
        lowStockThreshold: lowStockThreshold,
        compareAtPriceFcfa: compareAtPriceFcfa,
      );
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(supplierProductControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver ce produit ?'),
        content: const Text(
          'Le produit ne sera plus visible nulle part, y compris dans votre '
          'propre liste active. Cette action peut être vue comme une suppression.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(supplierProductControllerProvider.notifier)
        .setStatus(product: widget.product!, status: ProductStatus.archived);
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierProductControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Nouveau produit'),
        actions: [
          if (_isEditing && widget.product!.status != ProductStatus.archived)
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archiver',
              onPressed: _archive,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // No product-level photo picker: a product's photos always
                // come from its default variant (`product_variants_aggregate_products`
                // trigger, `0018_product_variants.sql`) — managed from
                // "Caractéristiques et variantes" below, not here.
                Text(
                  'Photos gérées depuis les caractéristiques et variantes '
                  'ci-dessous — ce produit affiche automatiquement celles '
                  'de sa variante par défaut.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Nom du produit',
                  controller: _nameController,
                  validator: Validators.required,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  validator: Validators.required,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProductCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    for (final category in ProductCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: AppSpacing.md),
                // Once a product has variants, its price/stock are
                // trigger-maintained aggregates (min price / summed stock
                // across variants, see `0018_product_variants.sql`) —
                // editing them here would just get silently overwritten by
                // the next variant change, so they become read-only and the
                // supplier edits per variant from the manager screen below.
                if (_hasVariants) ...[
                  _ReadOnlyAggregateRow(
                    priceLabel: _currentProduct!.maxPriceFcfa != null &&
                            _currentProduct!.maxPriceFcfa !=
                                _currentProduct!.priceFcfa
                        ? '${_currentProduct!.priceFcfa} – ${_currentProduct!.maxPriceFcfa} FCFA'
                        : '${_currentProduct!.priceFcfa} FCFA',
                    stockLabel:
                        '${_currentProduct!.stockQuantity} (${_currentProduct!.variantCount} variantes)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MtcTextField(
                    label: 'Prix barré (optionnel)',
                    controller: _compareAtPriceController,
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: MtcTextField(
                          label: 'Prix (FCFA)',
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveInteger,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MtcTextField(
                          label: 'Prix barré (optionnel)',
                          controller: _compareAtPriceController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        // Disabled at creation: a brand-new product has no
                        // variants yet, so it starts at 0 regardless of
                        // whatever's typed here — `_stockController`'s
                        // default text ("0") is exactly what `_submit` reads
                        // for `createProduct`. The real stock entry point is
                        // the variant manager below, right after creation;
                        // this field only becomes editable again once
                        // editing an existing, still variant-less product
                        // (see `_isEditing`), for manual corrections via
                        // `adjustStock`.
                        child: _isEditing
                            ? MtcTextField(
                                label: 'Stock',
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                validator: Validators.positiveInteger,
                              )
                            : _AggregateField(
                                label: 'Stock',
                                value: '0',
                                scheme: Theme.of(context).colorScheme,
                                helperText:
                                    'Défini après création, via les variantes',
                              ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MtcTextField(
                          label: 'Seuil stock faible (optionnel)',
                          controller: _lowStockThresholdController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: MtcTextField(
                        label: 'Poids (kg)',
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: Validators.positiveDecimal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MtcTextField(
                        label: 'Ville',
                        controller: _cityController,
                        validator: Validators.required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProductRegion>(
                  initialValue: _region,
                  decoration: const InputDecoration(labelText: 'Provenance'),
                  items: [
                    for (final region in ProductRegion.values)
                      DropdownMenuItem(value: region, child: Text(region.label)),
                  ],
                  onChanged: (value) =>
                      setState(() => _region = value ?? _region),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Je peux livrer moi-même'),
                  value: _allowsSelfDelivery,
                  onChanged: (value) =>
                      setState(() => _allowsSelfDelivery = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Livraison MTC disponible'),
                  value: _allowsMtcDelivery,
                  onChanged: (value) =>
                      setState(() => _allowsMtcDelivery = value),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Statut', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ProductStatus>(
                    segments: const [
                      ButtonSegment(
                        value: ProductStatus.draft,
                        label: Text('Brouillon'),
                      ),
                      ButtonSegment(
                        value: ProductStatus.active,
                        label: Text('Actif'),
                      ),
                      ButtonSegment(
                        value: ProductStatus.paused,
                        label: Text('En pause'),
                      ),
                    ],
                    selected: {
                      _status == ProductStatus.archived
                          ? ProductStatus.paused
                          : _status,
                    },
                    onSelectionChanged: (selection) =>
                        setState(() => _status = selection.first),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Caractéristiques et variantes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isEditing)
                  _variantPanelGeneration == 0
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : VariantManagerPanel(
                          key: _variantPanelKey,
                          product: _currentProduct!,
                          onComposingChanged: (composing) =>
                              setState(() => _isComposingVariant = composing),
                        )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Vous pourrez ajouter des caractéristiques (couleur, '
                        'stockage, taille…) une fois le produit créé.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const Divider(height: AppSpacing.xl),
                Text(
                  'Promotions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Même logique que les variantes : une remise désigne un
                // produit, donc il faut qu'il existe. Dans une feuille à
                // part et non ici, parce qu'on ne retouche pas ses
                // promotions au même moment qu'on corrige un libellé.
                if (_isEditing)
                  _PromotionsEntry(product: _currentProduct ?? widget.product!)
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Vous pourrez proposer des remises (sur la quantité, '
                        'sur une période…) une fois le produit créé.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                if (!_isComposingVariant)
                  MtcPrimaryButton(
                    label: _isEditing ? 'Enregistrer' : 'Créer le produit',
                    isLoading: state.isLoading,
                    onPressed: _submit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyAggregateRow extends StatelessWidget {
  const _ReadOnlyAggregateRow({
    required this.priceLabel,
    required this.stockLabel,
  });

  final String priceLabel;
  final String stockLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _AggregateField(label: 'Prix', value: priceLabel, scheme: scheme),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AggregateField(label: 'Stock', value: stockLabel, scheme: scheme),
        ),
      ],
    );
  }
}

class _AggregateField extends StatelessWidget {
  const _AggregateField({
    required this.label,
    required this.value,
    required this.scheme,
    this.helperText = 'Calculé depuis les variantes',
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, helperText: helperText),
      child: Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}

/// L'accès aux promotions depuis le formulaire : ce qui est en cours, et un
/// bouton pour gérer.
///
/// Résume au lieu de lister : le formulaire sert à décrire le produit, et
/// une liste de remises au milieu en ferait perdre le fil.
class _PromotionsEntry extends StatelessWidget {
  const _PromotionsEntry({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = [
      for (final promotion in product.promotions)
        if (promotion.isRunningAt()) promotion,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (running.isEmpty)
              Text(
                'Aucune promotion en cours.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final promotion in running)
                    PromotionBadge(promotion: promotion),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => SupplierPromotionsSheet(productId: product.id),
              ),
              icon: const Icon(Icons.local_offer_outlined),
              label: Text(
                product.promotions.isEmpty
                    ? 'Créer une promotion'
                    : 'Gérer les promotions (${product.promotions.length})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
