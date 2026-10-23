import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/core/error/user_message.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/promotion_pricing.dart';
import '../controllers/supplier_promotion_controller.dart';
import '../providers/supplier_product_providers.dart';

/// Gestion des promotions d'un produit.
///
/// Ouverte depuis le formulaire produit, une fois le produit enregistré :
/// une remise désigne un produit, donc il faut qu'il existe.
///
/// La feuille relit le produit dans le flux « Mes produits » plutôt que de
/// garder celui qu'on lui a passé : après chaque écriture la liste
/// ré-émet, et une copie figée afficherait encore la promotion qu'on vient
/// de supprimer.
class SupplierPromotionsSheet extends ConsumerWidget {
  const SupplierPromotionsSheet({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    if (supplierId == null) return const SizedBox.shrink();
    final products = ref.watch(myProductsProvider(supplierId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => AsyncValueWidget(
        value: products,
        data: (list) {
          final product = list.where((p) => p.id == productId).firstOrNull;
          if (product == null) {
            return const MtcEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Produit introuvable',
            );
          }
          return _Body(product: product, scrollController: controller);
        },
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.product, required this.scrollController});

  final Product product;
  final ScrollController scrollController;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// Le formulaire de création n'est pas affiché en permanence.
  ///
  /// Il l'était, et c'était trompeur : la feuille montrait côte à côte la
  /// liste des promotions et un formulaire déjà rempli de valeurs par
  /// défaut, de sorte qu'on ne savait plus si « Créer la promotion »
  /// modifiait celle du dessus ou en ajoutait une seconde. Il se déplie
  /// maintenant sur un bouton, et se replie dès que la promotion est
  /// enregistrée — le résultat apparaissant dans la liste au-dessus.
  bool _composing = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final promotions = product.promotions;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Promotions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${product.name} · prix de base '
          '${CurrencyFormatter.formatFcfa(product.priceFcfa)}',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        if (promotions.isEmpty)
          Text(
            'Aucune promotion. Celles que vous créez s\'appliquent '
            'automatiquement au prix payé par le client.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else ...[
          // Plusieurs remises peuvent coexister ; elles ne se cumulent pas.
          // La règle évite qu'un fournisseur croie offrir -35 % en posant
          // -15 % et -20 %, mais elle n'a pas à occuper trois lignes
          // au-dessus de la liste à chaque ouverture.
          const Align(
            alignment: Alignment.centerLeft,
            child: MtcHelpHint(
              label: 'Plusieurs remises sur un produit ?',
              title: 'Quand plusieurs promotions s\'appliquent',
              message:
                  'Le client paie la plus avantageuse — elles ne '
                  's\'additionnent pas.\n\n'
                  'Une remise sur quantité ne vaut qu\'à partir du nombre '
                  'd\'unités que vous avez fixé. En dessous, c\'est le prix '
                  'plein, ou une autre remise si elle s\'applique.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final promotion in promotions)
            _PromotionTile(promotion: promotion, product: product),
        ],
        const Divider(height: AppSpacing.xl),
        if (_composing)
          _NewPromotionForm(
            product: product,
            onCreated: () => setState(() => _composing = false),
            onCancel: () => setState(() => _composing = false),
          )
        else
          FilledButton.tonalIcon(
            onPressed: () => setState(() => _composing = true),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              promotions.isEmpty
                  ? 'Créer une promotion'
                  : 'Ajouter une promotion',
            ),
          ),
      ],
    );
  }
}

class _PromotionTile extends ConsumerWidget {
  const _PromotionTile({required this.promotion, required this.product});

  final Promotion promotion;
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(supplierPromotionControllerProvider.notifier);
    final isLoading = ref.watch(supplierPromotionControllerProvider).isLoading;
    final price = priceUnderPromotion(
      basePriceFcfa: product.priceFcfa,
      promotion: promotion,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    promotion.label?.trim().isNotEmpty == true
                        ? promotion.label!
                        : _describe(promotion),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _StatusChip(promotion: promotion),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_describe(promotion)} → '
              '${CurrencyFormatter.formatFcfa(price)} l\'unité',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (promotion.minQuantity > 1)
              Text(
                'À partir de ${promotion.minQuantity} unités',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            if (promotion.startsAt != null || promotion.endsAt != null)
              Text(
                _window(promotion),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                // Arrêter plutôt que supprimer : la reprendre ne demande
                // pas de la ressaisir.
                Switch(
                  value: promotion.isActive,
                  onChanged: isLoading
                      ? null
                      : (value) => controller.setActive(
                          id: promotion.id,
                          isActive: value,
                        ),
                ),
                Text(promotion.isActive ? 'Active' : 'Arrêtée'),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  tooltip: 'Supprimer',
                  onPressed: isLoading
                      ? null
                      : () => controller.remove(promotion.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(Promotion promotion) => switch (promotion.kind) {
    PromotionKind.percentage => '-${promotion.value}%',
    PromotionKind.fixedAmount =>
      '-${CurrencyFormatter.formatFcfa(promotion.value)}',
  };

  static String _window(Promotion promotion) {
    final from = promotion.startsAt;
    final until = promotion.endsAt;
    if (from != null && until != null) {
      return 'Du ${DateFormatter.formatDate(from)} '
          'au ${DateFormatter.formatDate(until)}';
    }
    if (from != null) return 'À partir du ${DateFormatter.formatDate(from)}';
    return 'Jusqu\'au ${DateFormatter.formatDate(until!)}';
  }
}

/// « En cours », « Programmée », « Terminée », « Arrêtée » : l'état réel, et
/// non le seul drapeau `is_active`. Une promotion active mais expirée ne
/// s'applique pas, et le fournisseur doit le lire sans calculer.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final (label, color) = switch (promotion) {
      _ when !promotion.isActive => ('Arrêtée', scheme.onSurfaceVariant),
      _ when promotion.endsAt != null && !now.isBefore(promotion.endsAt!) =>
        ('Terminée', scheme.onSurfaceVariant),
      _
          when promotion.startsAt != null &&
              now.isBefore(promotion.startsAt!) =>
        ('Programmée', scheme.tertiary),
      _ => ('En cours', scheme.primary),
    };

    return RoleBadge(label: label, color: color, icon: Icons.circle);
  }
}

class _NewPromotionForm extends ConsumerStatefulWidget {
  const _NewPromotionForm({
    required this.product,
    required this.onCreated,
    required this.onCancel,
  });

  final Product product;

  /// Prévient la feuille qu'une promotion est enregistrée, pour qu'elle
  /// replie le formulaire : la nouvelle est désormais visible dans la liste
  /// au-dessus, et laisser le formulaire ouvert invitait à la créer deux
  /// fois.
  final VoidCallback onCreated;
  final VoidCallback onCancel;

  @override
  ConsumerState<_NewPromotionForm> createState() => _NewPromotionFormState();
}

class _NewPromotionFormState extends ConsumerState<_NewPromotionForm> {
  PromotionKind _kind = PromotionKind.percentage;
  final _value = TextEditingController(text: '10');
  final _minQuantity = TextEditingController(text: '1');
  final _label = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    // L'aperçu du prix suit la saisie : une remise se juge au franc obtenu,
    // pas au pourcentage tapé.
    _value.addListener(_refresh);
    _minQuantity.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _value.removeListener(_refresh);
    _minQuantity.removeListener(_refresh);
    _value.dispose();
    _minQuantity.dispose();
    _label.dispose();
    super.dispose();
  }

  int? get _parsedValue {
    final value = int.tryParse(_value.text.trim());
    if (value == null || value <= 0) return null;
    // Même plafond qu'en base : annoncer plus serait promettre une écriture
    // qui sera refusée.
    if (_kind == PromotionKind.percentage && value > 90) return null;
    if (_kind == PromotionKind.fixedAmount &&
        value >= widget.product.priceFcfa) {
      return null;
    }
    return value;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startsAt : _endsAt) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        // Fin de journée : une promotion « jusqu'au 15 » doit couvrir le 15.
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _submit() async {
    final value = _parsedValue;
    if (value == null) return;
    final ok = await ref
        .read(supplierPromotionControllerProvider.notifier)
        .create(
          productId: widget.product.id,
          kind: _kind,
          value: value,
          minQuantity: int.tryParse(_minQuantity.text.trim()) ?? 1,
          startsAt: _startsAt,
          endsAt: _endsAt,
          label: _label.text.trim().isEmpty ? null : _label.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promotion enregistrée.')),
      );
      return;
    }
    final error = ref.read(supplierPromotionControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messagePourUtilisateur(error, repli: 'La promotion n\'a pas pu être créée.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(supplierPromotionControllerProvider).isLoading;
    final value = _parsedValue;
    final quantity = int.tryParse(_minQuantity.text.trim()) ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nouvelle promotion',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<PromotionKind>(
          segments: const [
            ButtonSegment(
              value: PromotionKind.percentage,
              label: Text('Pourcentage'),
              icon: Icon(Icons.percent_rounded),
            ),
            ButtonSegment(
              value: PromotionKind.fixedAmount,
              label: Text('Montant'),
              icon: Icon(Icons.money_off_csred_rounded),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (selection) =>
              setState(() => _kind = selection.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MtcTextField(
                controller: _value,
                label: _kind == PromotionKind.percentage
                    ? 'Remise (%)'
                    : 'Remise (FCFA)',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MtcTextField(
                controller: _minQuantity,
                label: 'Dès x unités',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        MtcTextField(
          controller: _label,
          label: 'Intitulé (facultatif)',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(isStart: true),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _startsAt == null
                      ? 'Début : immédiat'
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
        const SizedBox(height: AppSpacing.md),
        // L'aperçu est le vrai contrôle de saisie : -90% sur 25 000 F se
        // lit mieux en « 2 500 F l'unité » qu'en pourcentage.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: value == null
              ? Text(
                  _kind == PromotionKind.percentage
                      ? 'Entrez une remise entre 1 et 90 %.'
                      : 'Entrez une remise inférieure au prix de base.',
                  style: TextStyle(color: scheme.error),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        quantity > 1
                            ? 'À partir de $quantity unités'
                            : 'Dès la première unité',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    CurrencyText(
                      priceUnderPromotion(
                        basePriceFcfa: widget.product.priceFcfa,
                        promotion: Promotion(
                          id: '',
                          productId: widget.product.id,
                          kind: _kind,
                          value: value,
                        ),
                      ),
                      compareAtAmountFcfa: widget.product.priceFcfa,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        MtcPrimaryButton(
          label: 'Créer la promotion',
          isLoading: isLoading,
          onPressed: value == null ? null : _submit,
        ),
        TextButton(
          onPressed: isLoading ? null : widget.onCancel,
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
