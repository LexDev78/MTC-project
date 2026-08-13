import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/supplier_product_controller.dart';

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
  late final _sizesController = TextEditingController(
    text: widget.product?.sizes.join(', '),
  );
  late final _colorsController = TextEditingController(
    text: widget.product?.colors.join(', '),
  );

  late ProductCategory _category =
      widget.product?.category ?? ProductCategory.autre;
  late ProductRegion _region = widget.product?.region ?? ProductRegion.mali;
  late bool _allowsSelfDelivery = widget.product?.allowsSelfDelivery ?? true;
  late bool _allowsMtcDelivery = widget.product?.allowsMtcDelivery ?? true;
  late ProductStatus _status = widget.product?.status ?? ProductStatus.draft;
  late final List<String> _imageUrls = List.of(
    widget.product?.imageUrls ?? const [],
  );

  bool get _isEditing => widget.product != null;

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
    _sizesController.dispose();
    _colorsController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  int? _parseOptionalInt(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) setState(() => _imageUrls.add(file.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible d'accéder à la galerie. Vérifiez l'autorisation dans les réglages du téléphone.",
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
    final sizes = _splitCsv(_sizesController.text);
    final colors = _splitCsv(_colorsController.text);

    final controller = ref.read(supplierProductControllerProvider.notifier);
    bool success;

    if (_isEditing) {
      final original = widget.product!;
      success = await controller.updateProduct(
        original.copyWith(
          name: name,
          description: description,
          category: _category,
          priceFcfa: priceFcfa,
          compareAtPriceFcfa: compareAtPriceFcfa,
          weightKg: weightKg,
          city: city,
          imageUrls: _imageUrls,
          allowsSelfDelivery: _allowsSelfDelivery,
          allowsMtcDelivery: _allowsMtcDelivery,
          sizes: sizes,
          colors: colors,
          region: _region,
          lowStockThreshold: lowStockThreshold,
          status: _status,
        ),
      );
      final stockDelta = stockQuantity - original.stockQuantity;
      if (success && stockDelta != 0) {
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
        imageUrls: _imageUrls,
        allowsSelfDelivery: _allowsSelfDelivery,
        allowsMtcDelivery: _allowsMtcDelivery,
        sizes: sizes,
        colors: colors,
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
                _ImagePickerRow(
                  imageUrls: _imageUrls,
                  onAdd: _pickImage,
                  onRemove: (path) => setState(() => _imageUrls.remove(path)),
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
                      child: MtcTextField(
                        label: 'Stock',
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        validator: Validators.positiveInteger,
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
                MtcTextField(
                  label: 'Tailles (séparées par des virgules, optionnel)',
                  controller: _sizesController,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Couleurs (séparées par des virgules, optionnel)',
                  controller: _colorsController,
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
                const SizedBox(height: AppSpacing.xl),
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

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.imageUrls,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> imageUrls;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final path in imageUrls)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Image.file(
                      File(path),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 84,
                        height: 84,
                        color: scheme.surfaceContainerHigh,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(path),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: scheme.error,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
