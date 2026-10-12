import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/id_generator.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/product_characteristic_type.dart';
import '../../domain/entities/product_variant.dart';
import '../controllers/supplier_product_controller.dart';
import '../providers/characteristic_type_providers.dart';

/// The saveable result of a [VariantManagerPanel]'s current in-memory
/// draft — built on demand (not persisted by the panel itself) so the
/// embedding `SupplierProductFormScreen` can save it together with the
/// product's own fields in one combined submit.
typedef VariantDraft = ({
  List<ProductCharacteristic> characteristics,
  List<ProductVariant> variants,
});

/// Lets a supplier build a product's variants ("sous-caractéristiques") one
/// at a time: pick a characteristic type (only `approved`
/// `ProductCharacteristicType`s, see `approvedCharacteristicTypesProvider`),
/// give it a value, say whether that value costs extra, repeat to add more
/// fields to the same variant (e.g. stockage + couleur together), then add
/// photos and confirm — that's one variant done, ready to add another (e.g.
/// "256Go Noir", then "512Go Noir", then "256Go Rose"...). Embedded inline at
/// the bottom of `SupplierProductFormScreen`, which reads [VariantManagerPanelState.buildDraft]
/// through a `GlobalKey` and persists it alongside the product's own fields
/// when its single "Enregistrer" button is pressed — this panel has no save
/// button of its own.
class VariantManagerPanel extends ConsumerStatefulWidget {
  const VariantManagerPanel({
    super.key,
    required this.product,
    this.onComposingChanged,
  });

  /// Prévient l'écran hôte qu'une variante est en cours de composition, pour
  /// qu'il retire son propre bouton « Enregistrer » le temps que ça dure :
  /// « Enregistrer » et « Ajouter cette variante » côte à côte, c'est deux
  /// actions principales concurrentes dans la même colonne, dont une qui
  /// abandonne silencieusement le travail en cours.
  final ValueChanged<bool>? onComposingChanged;

  final Product product;

  @override
  ConsumerState<VariantManagerPanel> createState() => VariantManagerPanelState();
}

class VariantManagerPanelState extends ConsumerState<VariantManagerPanel> {
  /// The pool of characteristic types/values already used on this product —
  /// seeded from what's already saved, growing as the supplier introduces
  /// new type+value pairs while composing variants. Reusing an entry here
  /// keeps its price delta fixed (shared by every variant that picks it),
  /// rather than asking for it again each time.
  late final List<_CharacteristicDraft> _characteristics = [
    for (final c in widget.product.characteristics)
      _CharacteristicDraft(
        id: c.id,
        type: c.type,
        options: [
          for (final o in c.options)
            _OptionDraft(
              id: o.id,
              characteristicId: c.id,
              value: o.value,
              priceDeltaFcfa: o.priceDeltaFcfa,
            ),
        ],
      ),
  ];

  late final List<_VariantDraft> _variants = [
    for (final v in widget.product.variants)
      _VariantDraft(
        id: v.id,
        name: v.name,
        optionRefs: v.optionRefs,
        priceFcfa: v.priceFcfa,
        stockQuantity: v.stockQuantity,
        imageUrls: v.imageUrls,
        videoPath: v.videoPath,
        isDefault: v.isDefault,
      ),
  ];

  // ---- state for the variant currently being composed -------------------
  bool _isComposing = false;
  List<_ComposingField> _composingFields = [];
  List<String> _composingImages = [];
  String? _composingVideoPath;
  final _composingStockController = TextEditingController(text: '0');

  @override
  void dispose() {
    for (final v in _variants) {
      v.dispose();
    }
    _composingStockController.dispose();
    super.dispose();
  }

  String _refKey(ProductVariantOptionRef r) => '${r.characteristicId}:${r.optionId}';

  /// Prix du produit hors supplément d'option — la base sur laquelle se
  /// calcule chaque variante composée ici.
  ///
  /// `widget.product.priceFcfa` ne le donne plus dès qu'une variante existe :
  /// le trigger d'agrégation (`0018_product_variants.sql`) y écrit le
  /// **minimum** des prix de variantes. S'en servir comme base revenait à
  /// recompter un supplément déjà inclus — rouvrir la fiche d'un produit à
  /// 15 000 dont la seule variante porte « +2000 », puis en composer une
  /// nouvelle *sans* supplément, lui donnait 17 000 comme la première. Son
  /// prix ne suivait donc plus ses propres propriétés, et l'écart se
  /// réempilait à chaque passage.
  ///
  /// Deux cas, donc :
  /// - aucune variante enregistrée : le champ du produit *est* le prix de
  ///   base, le trigger n'y a pas encore touché ;
  /// - sinon : on le reconstitue depuis la variante par défaut telle
  ///   qu'elle est **enregistrée** — son prix moins les suppléments de ses
  ///   propres options.
  ///
  /// Volontairement lu sur `widget.product`, jamais sur le brouillon en
  /// cours : une base qui bougerait au fil des retouches de la session (prix
  /// corrigé à la main, supplément d'une valeur retapé) déplacerait le prix
  /// des variantes suivantes sans que rien ne l'explique.
  int get _basePriceFcfa {
    final product = widget.product;
    if (!product.hasVariants) return product.priceFcfa;

    final reference =
        product.variants.firstWhereOrNull((v) => v.isDefault) ??
        product.variants.firstOrNull;
    if (reference == null) return product.priceFcfa;

    return reference.priceFcfa -
        reference.optionRefs.fold<int>(0, (sum, ref) {
          final option = product.characteristics
              .firstWhereOrNull((c) => c.id == ref.characteristicId)
              ?.options
              .firstWhereOrNull((o) => o.id == ref.optionId);
          return sum + (option?.priceDeltaFcfa ?? 0);
        });
  }

  void _startComposing() {
    setState(() {
      _isComposing = true;
      _composingFields = [];
      _composingImages = [];
      _composingVideoPath = null;
      _composingStockController.text = '0';
    });
    widget.onComposingChanged?.call(true);
  }

  void _cancelComposing() {
    setState(() => _isComposing = false);
    widget.onComposingChanged?.call(false);
  }

  Future<void> _addField() async {
    final approvedTypes =
        ref.read(approvedCharacteristicTypesProvider).valueOrNull ?? const [];
    // Option ids already on *this* variant, across every type — not type
    // ids: a variant can now carry several options of the same
    // characteristic (e.g. sizes S, M and L together), so re-visiting
    // "Taille" is expected, only re-picking the exact same option isn't.
    final usedOptionIds = _composingFields.map((f) => f.option.id).toSet();
    final result = await showDialog<_AddFieldResult>(
      context: context,
      builder: (_) => _AddFieldDialog(
        approvedTypes: approvedTypes,
        characteristics: _characteristics,
        usedOptionIds: usedOptionIds,
        onProposeType: _proposeNewType,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      var characteristic = _characteristics.firstWhereOrNull(
        (c) => c.type.id == result.type.id,
      );
      if (characteristic == null) {
        characteristic = _CharacteristicDraft(
          id: IdGenerator.next(),
          type: result.type,
          options: [],
        );
        _characteristics.add(characteristic);
      }

      // `result.newValues` may carry more than one entry — e.g. a supplier
      // typing "S, M, L, XL" once for "Taille" instead of repeating
      // "Ajouter un champ" per size. Every value becomes its own option in
      // the pool *and* a field on this same variant — sizes aren't mutually
      // exclusive the way a single "Couleur" pick would be.
      final newOptions = [
        for (final value in result.newValues)
          _OptionDraft(
            id: IdGenerator.next(),
            characteristicId: characteristic.id,
            value: value,
            priceDeltaFcfa: result.newPriceDeltaFcfa,
          ),
      ];
      characteristic.options.addAll(newOptions);

      // An existing option can come back from the dialog with its price
      // just changed (see `_AddFieldDialogState._confirm`) — persist that
      // into the shared pool, not just onto this variant's own field, or
      // the next variant to reuse the same value would still see the old
      // price.
      for (final option in result.existingOptions) {
        final index = characteristic.options.indexWhere((o) => o.id == option.id);
        if (index != -1 &&
            characteristic.options[index].priceDeltaFcfa != option.priceDeltaFcfa) {
          characteristic.options[index] = option;
        }
      }

      for (final option in [...result.existingOptions, ...newOptions]) {
        _composingFields.add(
          _ComposingField(characteristicId: characteristic.id, type: result.type, option: option),
        );
      }
    });
  }

  void _removeComposingField(_ComposingField field) {
    setState(() => _composingFields.remove(field));
  }

  Future<void> _pickComposingImages() async {
    final paths = await _pickAndUploadImages();
    if (paths.isNotEmpty && mounted) {
      setState(() => _composingImages.addAll(paths));
    }
  }

  /// Plusieurs photos en une seule fois (`pickMultiImage`).
  ///
  /// Une variante en a rarement une seule, et rouvrir la galerie pour chacune
  /// était l'essentiel du temps passé à en composer une.
  ///
  /// Chaque envoi est tenté séparément : sur dix photos sélectionnées, une
  /// seule trop lourde ne doit pas faire perdre les neuf autres, déjà
  /// téléversées. Ce qui a échoué est annoncé, le reste est gardé.
  Future<List<String>> _pickAndUploadImages() async {
    final List<XFile> files;
    try {
      files = await ImagePicker().pickMultiImage(imageQuality: 85);
    } catch (_) {
      _signalerEchecMedia("Impossible d'ouvrir la galerie.");
      return const [];
    }
    if (files.isEmpty) return const [];

    final supplierId = ref.read(operatingSupplierIdProvider);
    final client = ref.read(supabaseClientProvider);
    final paths = <String>[];
    var echecs = 0;
    for (final file in files) {
      try {
        paths.add(
          await uploadPickedImage(
            client: client,
            bucket: 'product-images',
            folder: supplierId!,
            file: file,
          ),
        );
      } catch (_) {
        echecs++;
      }
    }
    if (echecs > 0) {
      _signalerEchecMedia(
        echecs == 1
            ? "Une photo n'a pas pu être ajoutée."
            : "$echecs photos n'ont pas pu être ajoutées.",
      );
    }
    return paths;
  }

  Future<void> _pickComposingVideo() async {
    final path = await _pickAndUploadVideo();
    if (path != null && mounted) setState(() => _composingVideoPath = path);
  }

  /// Une courte vidéo de présentation, dans le bucket `product-videos`
  /// (`0044_variant_video.sql`).
  ///
  /// [maxDuration] est une consigne donnée au sélecteur, pas une garantie :
  /// selon la plateforme il propose de rogner la vidéo, ou l'ignore pour un
  /// fichier déjà présent dans la galerie. Ce qui tient vraiment, c'est le
  /// plafond de 25 Mo du bucket (vérifié aussi côté client dans
  /// `uploadPickedImage`), qui écarte de fait les longues vidéos.
  Future<String?> _pickAndUploadVideo() async {
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (file == null) return null;
      final supplierId = ref.read(operatingSupplierIdProvider);
      return await uploadPickedImage(
        client: ref.read(supabaseClientProvider),
        bucket: 'product-videos',
        folder: supplierId!,
        file: file,
        // `XFile.mimeType` n'est renseigné que par certaines plateformes :
        // l'extension est le seul indice fiable, et une vidéo envoyée sans
        // type (donc `image/jpeg` par défaut) serait refusée par le bucket.
        contentType: file.name.toLowerCase().endsWith('.mov')
            ? 'video/quicktime'
            : 'video/mp4',
      );
    } catch (e) {
      _signalerEchecMedia("Impossible d'ajouter cette vidéo. $e");
      return null;
    }
  }

  void _signalerEchecMedia(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _finishComposingVariant() {
    if (_composingFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un champ (couleur, stockage…).')),
      );
      return;
    }
    final optionRefs = [
      for (final f in _composingFields)
        ProductVariantOptionRef(characteristicId: f.characteristicId, optionId: f.option.id),
    ];
    final refSet = optionRefs.map(_refKey).toSet();
    final duplicate = _variants.any((v) {
      final vSet = v.optionRefs.map(_refKey).toSet();
      return vSet.length == refSet.length && vSet.containsAll(refSet);
    });
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette combinaison existe déjà.')),
      );
      return;
    }

    // Un supplément **par caractéristique**, pas un par valeur.
    //
    // Une variante peut porter plusieurs valeurs d'une même caractéristique
    // quand elles se vendent ensemble au même prix — les tailles S, M et L
    // d'un même t-shirt. Additionner leurs suppléments n'a alors aucun sens :
    // le client n'achète qu'une taille.
    //
    // Et quand ces valeurs n'ont **pas** le même supplément — « 512 Go » à
    // +50 000 et « 1 To » à +120 000 — les réunir sur une seule variante est
    // une erreur de saisie, pas un cas à arbitrer : ce sont deux produits
    // vendus à deux prix. L'addition donnait le cumul des deux ; choisir
    // l'un des deux en silence donnerait un prix faux pour l'autre. On le
    // signale donc, en nommant la caractéristique fautive.
    final deltasParCaracteristique = <String, Set<int>>{};
    final libelles = <String, String>{};
    for (final field in _composingFields) {
      deltasParCaracteristique
          .putIfAbsent(field.characteristicId, () => <int>{})
          .add(field.option.priceDeltaFcfa);
      libelles[field.characteristicId] = field.type.label;
    }

    final divergente = deltasParCaracteristique.entries
        .where((e) => e.value.length > 1)
        .firstOrNull;
    if (divergente != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Les valeurs de « ${libelles[divergente.key]} » n\'ont pas le '
            'même supplément : faites-en des variantes séparées.',
          ),
        ),
      );
      return;
    }

    final delta = deltasParCaracteristique.values.fold<int>(
      0,
      (sum, deltas) => sum + deltas.first,
    );
    final name = _composingFields.map((f) => f.option.value).join(' ');

    setState(() {
      _variants.add(
        _VariantDraft(
          id: IdGenerator.next(),
          name: name,
          optionRefs: optionRefs,
          priceFcfa: _basePriceFcfa + delta,
          stockQuantity: int.tryParse(_composingStockController.text.trim()) ?? 0,
          imageUrls: List.of(_composingImages),
          videoPath: _composingVideoPath,
          isDefault: _variants.isEmpty,
        ),
      );
      _isComposing = false;
    });
    widget.onComposingChanged?.call(false);
  }

  void _removeVariant(_VariantDraft variant) {
    setState(() {
      _variants.remove(variant);
      if (_variants.isNotEmpty && !_variants.any((v) => v.isDefault)) {
        _variants.first.isDefault = true;
      }
      variant.dispose();
    });
  }

  Future<void> _pickVariantImages(_VariantDraft variant) async {
    final paths = await _pickAndUploadImages();
    if (paths.isNotEmpty && mounted) {
      setState(() => variant.imageUrls.addAll(paths));
    }
  }

  Future<void> _pickVariantVideo(_VariantDraft variant) async {
    final path = await _pickAndUploadVideo();
    if (path != null && mounted) setState(() => variant.videoPath = path);
  }

  Future<void> _proposeNewType() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proposer un nouveau type'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex : Matière, Capacité…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Proposer'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty || !mounted) return;
    final ok = await ref
        .read(supplierProductControllerProvider.notifier)
        .proposeCharacteristicType(label);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Proposition envoyée — en attente de validation par MTC.'
              : "Impossible d'envoyer la proposition.",
        ),
      ),
    );
  }

  /// Whether the current draft has at least one variant — read by
  /// `SupplierProductFormScreen` to decide whether "Actif" is reachable in
  /// the same submit that first composes variants (before anything here has
  /// ever been saved to the database).
  bool get hasVariants => _variants.isNotEmpty;

  /// Converts the current in-memory draft into saveable entities, for
  /// `SupplierProductFormScreen._submit` to pass to
  /// `ProductRepository.replaceCharacteristicsAndVariants` alongside the
  /// product's own fields — this panel never calls that itself.
  ///
  /// Only options at least one variant actually references make it out —
  /// `_addField` adds an option to its characteristic's pool the moment
  /// it's picked in the composer, before the variant being built is ever
  /// confirmed. Cancelling that variant (or later deleting one that used a
  /// value no other variant shares) leaves the option sitting in the pool
  /// with nothing pointing at it; saving it anyway would show the client a
  /// swatch/chip for a combination that can never resolve to a real variant
  /// (permanently "unreachable" — see `_VariantPicker`'s `reachable`,
  /// `product_detail_screen.dart`).
  VariantDraft buildDraft() {
    final usedOptionIds = <String>{
      for (final v in _variants) for (final r in v.optionRefs) r.optionId,
    };

    final characteristics = <ProductCharacteristic>[];
    for (final c in _characteristics) {
      final usedOptions = c.options.where((o) => usedOptionIds.contains(o.id)).toList();
      if (usedOptions.isEmpty) continue;
      characteristics.add(
        ProductCharacteristic(
          id: c.id,
          productId: widget.product.id,
          type: c.type,
          displayOrder: characteristics.length,
          options: [
            for (var j = 0; j < usedOptions.length; j++)
              ProductCharacteristicOption(
                id: usedOptions[j].id,
                characteristicId: c.id,
                value: usedOptions[j].value,
                priceDeltaFcfa: usedOptions[j].priceDeltaFcfa,
                displayOrder: j,
              ),
          ],
        ),
      );
    }
    final variants = [
      for (var i = 0; i < _variants.length; i++)
        _variants[i].toEntity(productId: widget.product.id, displayOrder: i),
    ];
    return (characteristics: characteristics, variants: variants);
  }

  @override
  Widget build(BuildContext context) {
    final approvedTypesAsync = ref.watch(approvedCharacteristicTypesProvider);

    return AsyncValueWidget(
      value: approvedTypesAsync,
      data: (approvedTypes) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_variants.isNotEmpty) ...[
              Text(
                'Variantes (${_variants.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<String>(
                groupValue: _variants.firstWhereOrNull((v) => v.isDefault)?.id,
                onChanged: (id) => setState(() {
                  for (final v in _variants) {
                    v.isDefault = v.id == id;
                  }
                }),
                child: Column(
                  children: [
                    for (final variant in _variants)
                      _VariantTile(
                        variant: variant,
                        onPickImages: () => _pickVariantImages(variant),
                        onRemoveImage: (path) =>
                            setState(() => variant.imageUrls.remove(path)),
                        onPickVideo: () => _pickVariantVideo(variant),
                        onRemoveVideo: () =>
                            setState(() => variant.videoPath = null),
                        onRemove: () => _removeVariant(variant),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_isComposing)
              _VariantComposer(
                fields: _composingFields,
                basePriceFcfa: _basePriceFcfa,
                images: _composingImages,
                videoPath: _composingVideoPath,
                stockController: _composingStockController,
                onAddField: _addField,
                onRemoveField: _removeComposingField,
                onPickImages: _pickComposingImages,
                onRemoveImage: (path) => setState(() => _composingImages.remove(path)),
                onPickVideo: _pickComposingVideo,
                onRemoveVideo: () => setState(() => _composingVideoPath = null),
                onCancel: _cancelComposing,
                onConfirm: _finishComposingVariant,
              )
            else ...[
              // Une seule porte d'entrée. « Ajouter des valeurs » vivait ici
              // en second bouton pour pré-définir un pool (« Taille : S, M,
              // L ») sans composer de variante — mais le dialogue « Ajouter
              // un champ » accepte déjà la même saisie séparée par des
              // virgules, et chaque valeur qu'il crée rejoint ce même pool,
              // d'où elle revient en pastille réutilisable sur les variantes
              // suivantes. Deux chemins pour un seul résultat, dont un qui
              // n'était qu'un détour.
              OutlinedButton.icon(
                onPressed: _startComposing,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Ajouter une variante'),
              ),
            ],
            // « Proposer un nouveau type » ne s'empile plus ici en
            // permanence : c'est une demande rare (le type proposé part en
            // validation chez MTC et n'est utilisable que plus tard), qui
            // n'a de sens qu'au moment précis où le type cherché manque dans
            // la liste — donc dans le dialogue « Ajouter un champ », juste
            // sous le menu des types.
          ],
        );
      },
    );
  }
}

/// One type+value pair added to the variant currently being composed.
class _ComposingField {
  _ComposingField({required this.characteristicId, required this.type, required this.option});

  final String characteristicId;
  final ProductCharacteristicType type;
  final _OptionDraft option;
}

/// A characteristic type this product uses, with the pool of values
/// introduced so far (each variant that reuses one of these inherits its
/// price delta rather than re-asking for it).
class _CharacteristicDraft {
  _CharacteristicDraft({required this.id, required this.type, required List<_OptionDraft> options})
    : options = List.of(options);

  final String id;
  final ProductCharacteristicType type;
  final List<_OptionDraft> options;
}

class _OptionDraft {
  const _OptionDraft({
    required this.id,
    required this.characteristicId,
    required this.value,
    required this.priceDeltaFcfa,
  });

  final String id;
  final String characteristicId;
  final String value;
  final int priceDeltaFcfa;
}

/// In-memory edit state for one composed variant — mirrors [ProductVariant]
/// but with mutable controllers so this screen can edit stock/photos before
/// [toEntity] converts it back for saving. [priceFcfa] is seeded from the
/// sum of its fields' deltas but stays editable, in case the supplier wants
/// to round or override the computed figure.
class _VariantDraft {
  _VariantDraft({
    required this.id,
    required this.name,
    required this.optionRefs,
    required int priceFcfa,
    required int stockQuantity,
    required List<String> imageUrls,
    required this.isDefault,
    this.videoPath,
  }) : priceController = TextEditingController(text: priceFcfa.toString()),
       stockController = TextEditingController(text: stockQuantity.toString()),
       imageUrls = List.of(imageUrls);

  final String id;
  final String name;
  final List<ProductVariantOptionRef> optionRefs;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final List<String> imageUrls;

  /// Une seule vidéo par variante, remplacée plutôt qu'accumulée.
  String? videoPath;
  bool isDefault;

  ProductVariant toEntity({required String productId, required int displayOrder}) {
    return ProductVariant(
      id: id,
      productId: productId,
      name: name,
      priceFcfa: int.tryParse(priceController.text.trim()) ?? 0,
      stockQuantity: int.tryParse(stockController.text.trim()) ?? 0,
      imageUrls: imageUrls,
      videoPath: videoPath,
      isDefault: isDefault,
      displayOrder: displayOrder,
      optionRefs: optionRefs,
    );
  }

  void dispose() {
    priceController.dispose();
    stockController.dispose();
  }
}

/// The panel shown while composing one new variant: the fields added so
/// far, a way to add more, a photo strip, a stock field, and
/// confirm/cancel — matches the flow: pick a characteristic type + value +
/// optional extra cost, repeat for as many fields as this variant needs
/// (e.g. stockage then couleur), add photos, confirm.
class _VariantComposer extends StatelessWidget {
  const _VariantComposer({
    required this.fields,
    required this.basePriceFcfa,
    required this.images,
    required this.videoPath,
    required this.stockController,
    required this.onAddField,
    required this.onRemoveField,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onPickVideo,
    required this.onRemoveVideo,
    required this.onCancel,
    required this.onConfirm,
  });

  final List<_ComposingField> fields;

  /// Prix du produit hors supplément, auquel s'ajoutent ceux des champs de
  /// cette variante — voir `VariantManagerPanelState._basePriceFcfa`.
  final int basePriceFcfa;

  final List<String> images;
  final String? videoPath;
  final TextEditingController stockController;
  final VoidCallback onAddField;
  final ValueChanged<_ComposingField> onRemoveField;
  final VoidCallback onPickImages;
  final ValueChanged<String> onRemoveImage;
  final VoidCallback onPickVideo;
  final VoidCallback onRemoveVideo;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouvelle variante', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (fields.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final field in fields)
                    InputChip(
                      label: Text(
                        field.option.priceDeltaFcfa != 0
                            ? '${field.type.label} : ${field.option.value} (+${field.option.priceDeltaFcfa})'
                            : '${field.type.label} : ${field.option.value}',
                      ),
                      onDeleted: () => onRemoveField(field),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onAddField,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un champ'),
            ),
            const SizedBox(height: AppSpacing.md),
            // Le prix se calculait en silence à la validation : on ajoutait
            // « Couleur : Rouge (+2000) » sans jamais voir ce que ça donnait,
            // et il fallait valider la variante pour le découvrir dans sa
            // vignette. Il s'affiche maintenant ici, et bouge à chaque champ
            // ajouté ou retiré.
            _ComposedPrice(basePriceFcfa: basePriceFcfa, fields: fields),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Stock pour cette variante',
              controller: stockController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Photos', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final path in images)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: ResolvedImage(path: path, bucket: 'product-images'),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => onRemoveImage(path),
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: scheme.error,
                                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    onTap: onPickImages,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _VideoSlot(
              videoPath: videoPath,
              onPick: onPickVideo,
              onRemove: onRemoveVideo,
            ),
            const SizedBox(height: AppSpacing.md),
            // Pas deux moitiés égales : « Ajouter cette variante » ne tient
            // pas dans la moitié d'une largeur de téléphone et
            // `MtcPrimaryButton` tronque alors son libellé à « Ajouter
            // cette ... », ce qui laisse l'action principale du composeur
            // illisible. « Annuler » se contente très bien du tiers
            // restant.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: MtcPrimaryButton(
                    label: 'Ajouter cette variante',
                    onPressed: onConfirm,
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

/// Emplacement de la vidéo d'une variante : un bouton tant qu'il n'y en a
/// pas, sinon une ligne qui la nomme et permet de la retirer.
///
/// Une seule vidéo par variante, et pas de lecteur ici : côté fournisseur,
/// ce qui compte est de savoir qu'elle est attachée. Embarquer un lecteur
/// dans un formulaire déjà long coûterait une dépendance et un contrôleur à
/// gérer pour une vignette que personne ne regarde deux fois.
class _VideoSlot extends StatelessWidget {
  const _VideoSlot({
    required this.videoPath,
    required this.onPick,
    required this.onRemove,
  });

  final String? videoPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = videoPath;

    if (path == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.videocam_outlined, size: 20),
          label: const Text('Ajouter une courte vidéo'),
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.play_circle_outline_rounded, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Vidéo ajoutée',
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('Remplacer')),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          tooltip: 'Retirer la vidéo',
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// Prix de la variante en cours de composition : la base du produit plus les
/// suppléments de ses champs, avec le détail du calcul tant qu'il y a un
/// supplément à expliquer.
class _ComposedPrice extends StatelessWidget {
  const _ComposedPrice({required this.basePriceFcfa, required this.fields});

  final int basePriceFcfa;
  final List<_ComposingField> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = fields.fold<int>(0, (sum, f) => sum + f.option.priceDeltaFcfa);

    // Le détail du calcul sur sa propre ligne, pas dans une colonne à droite
    // du libellé : « 15 000 FCFA + 2 000 de supplément » n'a aucune chance de
    // tenir dans la moitié d'une largeur de téléphone, et débordait de la
    // carte (53 px, rayures jaunes et noires à l'appui).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Prix de cette variante', style: theme.textTheme.bodyMedium),
            const Spacer(),
            CurrencyText(
              basePriceFcfa + delta,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        if (delta != 0)
          Text(
            '${CurrencyFormatter.formatFcfa(basePriceFcfa)} '
            '+ ${CurrencyFormatter.formatFcfa(delta)} de supplément',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Le libellé d'exemple, le suffixe et le clavier propres à chaque type de
/// caractéristique, pour [_AddFieldDialog].
String _valueHintFor(String? typeId) => switch (typeId) {
  'couleur' => 'Ex : Noir, Rouge, Bleu…',
  'taille' => 'Ex : S, M, L, 42…',
  _ => 'Valeur',
};

String? _valueSuffixFor(String? typeId) => switch (typeId) {
  'stockage' => 'Go',
  'poids' => 'kg',
  _ => null,
};

bool _isNumericValueFor(String? typeId) => typeId == 'stockage' || typeId == 'poids';

/// Result of [_AddFieldDialog]: any number of existing [_OptionDraft]s
/// reused as-is (each one's price delta is fixed, shared by every variant
/// using it) plus any number of brand new values (+ a shared delta) to
/// create — a supplier typing "S, M, L, XL" for "Taille" once populates all
/// four, not a single option literally named "S, M, L, XL", and can combine
/// that with tapping existing chips in the same confirm. A variant can
/// carry several of these for the same characteristic (e.g. sizes S, M and
/// L together on one variant) — see `0025_multi_option_variant_options.sql`.
class _AddFieldResult {
  const _AddFieldResult({
    required this.type,
    this.existingOptions = const [],
    this.newValues = const [],
    this.newPriceDeltaFcfa = 0,
  });

  final ProductCharacteristicType type;
  final List<_OptionDraft> existingOptions;
  final List<String> newValues;
  final int newPriceDeltaFcfa;
}

/// Dialog for adding one or more type+value fields to the variant being
/// composed, all at once. Picking a type that already has values on this
/// product offers them as quick-reuse chips (delta inherited, not
/// re-asked) — tap as many as apply (e.g. every size this variant comes
/// in) — alongside a text field for anything not in the pool yet.
class _AddFieldDialog extends StatefulWidget {
  const _AddFieldDialog({
    required this.approvedTypes,
    required this.characteristics,
    required this.usedOptionIds,
    required this.onProposeType,
  });

  final List<ProductCharacteristicType> approvedTypes;
  final List<_CharacteristicDraft> characteristics;

  /// Ouvert depuis ce dialogue, au moment où le type cherché s'avère absent
  /// du menu — voir le commentaire du panneau, d'où ce bouton a été retiré.
  final VoidCallback onProposeType;

  /// Option ids already on the variant being composed — filtered out of the
  /// reuse chips so a stray re-tap can't attach the exact same option twice.
  final Set<String> usedOptionIds;

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  ProductCharacteristicType? _type;
  final Set<_OptionDraft> _selectedExisting = {};
  final _valueController = TextEditingController();
  bool _hasExtraCost = false;
  final _deltaController = TextEditingController(text: '0');
  String? _error;

  @override
  void dispose() {
    _valueController.dispose();
    _deltaController.dispose();
    super.dispose();
  }

  List<_OptionDraft> get _existingOptionsForType {
    final type = _type;
    if (type == null) return const [];
    final all =
        widget.characteristics.firstWhereOrNull((c) => c.type.id == type.id)?.options ??
        const [];
    return [for (final o in all) if (!widget.usedOptionIds.contains(o.id)) o];
  }

  String get _valueHint => _valueHintFor(_type?.id);

  String? get _valueSuffix => _valueSuffixFor(_type?.id);

  bool get _isNumericValue => _isNumericValueFor(_type?.id);

  void _confirm() {
    final type = _type;
    if (type == null) {
      setState(() => _error = 'Choisissez un type de caractéristique.');
      return;
    }

    final suffix = _valueSuffix;
    final pool =
        widget.characteristics.firstWhereOrNull((c) => c.type.id == type.id)?.options ??
        const <_OptionDraft>[];
    // Comma-separated bulk entry — "S, M, L, XL" in one go for "Taille"
    // rather than repeating this dialog per size — matches the hint text
    // above, which has always shown a comma-separated example. A typed
    // piece that already matches a pool value is treated as picking that
    // chip (avoids a duplicate option the database would reject) rather
    // than silently dropped.
    final pieces = _valueController.text
        .trim()
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => suffix != null ? '$p $suffix' : p)
        .toList();

    final delta = _hasExtraCost ? (int.tryParse(_deltaController.text.trim()) ?? 0) : 0;

    final selected = {..._selectedExisting};
    final newValues = <String>[];
    for (final piece in pieces) {
      final match = pool.firstWhereOrNull((o) => o.value == piece);
      if (match != null) {
        // A typed value that happens to already exist in the pool used to
        // silently reuse *that* option's stored delta, discarding whatever
        // was just entered here — "Coût supplémentaire ?" only ever worked
        // the very first time a value was typed, never again afterwards
        // (e.g. a value pre-defined with no price via "Ajouter des
        // valeurs", then priced from this dialog later). Only overridden
        // when the checkbox is actually ticked with a different amount, so
        // picking an existing value via free text without touching the
        // checkbox still just reuses its current price unchanged.
        selected.add(
          _hasExtraCost && delta != match.priceDeltaFcfa
              ? _OptionDraft(
                  id: match.id,
                  characteristicId: match.characteristicId,
                  value: match.value,
                  priceDeltaFcfa: delta,
                )
              : match,
        );
      } else {
        newValues.add(piece);
      }
    }
    selected.removeWhere((o) => widget.usedOptionIds.contains(o.id));

    if (selected.isEmpty && newValues.isEmpty) {
      setState(() => _error = 'Sélectionnez ou saisissez au moins une valeur.');
      return;
    }

    Navigator.of(context).pop(
      _AddFieldResult(
        type: type,
        existingOptions: selected.toList(),
        newValues: newValues,
        newPriceDeltaFcfa: delta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingOptions = _existingOptionsForType;
    return AlertDialog(
      title: const Text('Ajouter un champ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ProductCharacteristicType>(
              key: const Key('add-field-type-dropdown'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type de caractéristique'),
              items: [
                for (final t in widget.approvedTypes)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (value) => setState(() {
                _type = value;
                _selectedExisting.clear();
                _error = null;
              }),
            ),
            // Discret à dessein : c'est une porte de sortie pour le cas rare
            // où le type cherché manque, pas une étape du remplissage. Au
            // poids d'un bouton ordinaire, il coupait visuellement le type
            // de sa valeur, juste en dessous.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onProposeType,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
                child: const Text('Proposer un nouveau type'),
              ),
            ),
            if (_type != null) ...[
              if (existingOptions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Valeurs déjà utilisées — touchez-en plusieurs si elles '
                  's\'appliquent toutes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final option in existingOptions)
                      FilterChip(
                        label: Text(
                          option.priceDeltaFcfa != 0
                              ? '${option.value} (+${option.priceDeltaFcfa})'
                              : option.value,
                        ),
                        selected: _selectedExisting.contains(option),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _selectedExisting.add(option);
                          } else {
                            _selectedExisting.remove(option);
                          }
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('add-field-value-input'),
                controller: _valueController,
                keyboardType: _isNumericValue ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(
                  labelText: _valueHint,
                  suffixText: _valueSuffix,
                  helperText: 'Plusieurs valeurs ? Séparez-les par des virgules.',
                ),
              ),
              CheckboxListTile(
                key: const Key('add-field-extra-cost-checkbox'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Coût supplémentaire ?'),
                value: _hasExtraCost,
                onChanged: (value) => setState(() => _hasExtraCost = value ?? false),
              ),
              if (_hasExtraCost)
                TextField(
                  key: const Key('add-field-delta-input'),
                  controller: _deltaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(onPressed: _confirm, child: const Text('Ajouter')),
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onPickVideo,
    required this.onRemoveVideo,
    required this.onRemove,
  });

  final _VariantDraft variant;
  final VoidCallback onPickImages;
  final ValueChanged<String> onRemoveImage;
  final VoidCallback onPickVideo;
  final VoidCallback onRemoveVideo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    variant.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Tooltip(
                  message: 'Variante par défaut',
                  child: Radio<String>(value: variant.id),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  tooltip: 'Supprimer cette variante',
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: MtcTextField(
                    label: 'Prix (FCFA)',
                    controller: variant.priceController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MtcTextField(
                    label: 'Stock',
                    controller: variant.stockController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final path in variant.imageUrls)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: ResolvedImage(path: path, bucket: 'product-images'),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => onRemoveImage(path),
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: scheme.error,
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    onTap: onPickImages,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            _VideoSlot(
              videoPath: variant.videoPath,
              onPick: onPickVideo,
              onRemove: onRemoveVideo,
            ),
          ],
        ),
      ),
    );
  }
}
