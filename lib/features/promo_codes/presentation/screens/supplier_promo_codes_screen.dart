import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/presentation/widgets/product_multi_picker.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/core/error/user_message.dart';

import '../../domain/entities/promo_code.dart';
import '../controllers/promo_code_controller.dart';
import '../providers/promo_code_providers.dart';

/// Les codes promo du fournisseur : ce qu'il distribue, et ce qu'ils ont
/// remisé.
///
/// Un code n'est pas une promotion : il ne s'applique pas tout seul, il est
/// **remis à quelqu'un**. L'écran s'organise donc autour de ce qu'un
/// fournisseur veut savoir d'un code distribué — combien de fois il a servi,
/// sur quels articles, et combien il lui a coûté.
class SupplierPromoCodesScreen extends ConsumerStatefulWidget {
  const SupplierPromoCodesScreen({super.key});

  @override
  ConsumerState<SupplierPromoCodesScreen> createState() =>
      _SupplierPromoCodesScreenState();
}

class _SupplierPromoCodesScreenState
    extends ConsumerState<SupplierPromoCodesScreen> {
  /// Même choix que la feuille des promotions : le formulaire se déplie sur
  /// un bouton. Affiché en permanence sous la liste, on ne sait plus si
  /// « Créer » ajoute un code ou modifie celui du dessus.
  bool _composing = false;

  /// Le code que l'on corrige, s'il y en a un. `null` en création.
  PromoCode? _editing;

  @override
  Widget build(BuildContext context) {
    final codesAsync = ref.watch(myPromoCodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes promo'),
        // Les règles passent derrière le « ? » : elles comptent — un
        // fournisseur qui laisse tourner un -20 % et distribue un code
        // -20 % ne pense pas vendre à -36 % — mais elles n'ont pas à
        // repousser la liste vers le bas à chaque visite.
        actions: const [
          MtcHelpAction(
            title: 'Comment marchent les codes promo',
            message:
                'Un code promo ne s\'applique qu\'à vos produits, et seulement '
                'pour les clients à qui vous le donnez.\n\n'
                'Si une promotion automatique est déjà plus avantageuse sur '
                'un article, c\'est elle qui s\'applique — les deux remises ne '
                's\'additionnent jamais.\n\n'
                'Un code peut couvrir tous vos produits ou seulement '
                'certains, être limité dans le temps, en nombre '
                'd\'utilisations, ou demander un montant minimum de commande.',
          ),
        ],
      ),
      body: AsyncValueWidget(
        value: codesAsync,
        data: (codes) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (codes.isEmpty)
              const MtcEmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'Aucun code promo',
                subtitle:
                    'Créez un code, donnez-le à vos clients, et retrouvez ici '
                    'ce qu\'il a remisé.',
              )
            else
              for (final code in codes)
                _PromoCodeCard(
                  code: code,
                  onEdit: () => setState(() {
                    _editing = code;
                    _composing = true;
                  }),
                ),
            const SizedBox(height: AppSpacing.lg),
            if (_composing)
              _PromoCodeForm(
                key: ValueKey(_editing?.id ?? 'nouveau'),
                existing: _editing,
                onDone: () => setState(() {
                  _composing = false;
                  _editing = null;
                }),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => setState(() {
                  _editing = null;
                  _composing = true;
                }),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  codes.isEmpty ? 'Créer un code' : 'Ajouter un code',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PromoCodeCard extends ConsumerWidget {
  const _PromoCodeCard({required this.code, required this.onEdit});

  final PromoCode code;

  /// Rouvre le code dans le formulaire, déjà rempli.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final controller = ref.read(promoCodeControllerProvider.notifier);
    final isLoading = ref.watch(promoCodeControllerProvider).isLoading;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Le code en évidence : c'est ce que le fournisseur recopie
                // dans un message pour le donner.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    code.code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '-${code.percent}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _StatusChip(code: code),
              ],
            ),
            if (code.label != null && code.label!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(code.label!),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              _coverage(code),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            Text(_limits(code), style: TextStyle(color: scheme.onSurfaceVariant)),
            if (code.startsAt != null || code.endsAt != null)
              Text(
                _window(code),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (code.redemptions.isEmpty)
              Text(
                'Jamais utilisé pour l\'instant.',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              // Le détail est replié : un code très utilisé ferait sinon
              // plusieurs écrans de haut.
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  '${code.redemptions.length} utilisation'
                  '${code.redemptions.length > 1 ? 's' : ''} · '
                  '${CurrencyFormatter.formatFcfa(code.totalDiscountFcfa)} remisés',
                  style: theme.textTheme.labelLarge,
                ),
                children: [
                  for (final redemption in code.redemptions)
                    _RedemptionTile(redemption: redemption),
                ],
              ),
            const Divider(),
            Row(
              children: [
                Switch(
                  value: code.isActive,
                  onChanged: isLoading
                      ? null
                      : (value) =>
                            controller.setActive(id: code.id, isActive: value),
                ),
                Text(code.isActive ? 'Actif' : 'Arrêté'),
                const Spacer(),
                TextButton.icon(
                  onPressed: isLoading ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  tooltip: 'Supprimer',
                  onPressed: isLoading ? null : () => controller.remove(code.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _coverage(PromoCode code) => code.productIds.isEmpty
      ? 'S\'applique à tous vos produits.'
      : 'S\'applique à ${code.productIds.length} produit'
            '${code.productIds.length > 1 ? 's' : ''}.';

  static String _limits(PromoCode code) {
    final restant = code.remainingUses;
    final global = restant == null
        ? 'Utilisations illimitées'
        : '${code.usesCount}/${code.maxUses} utilisations';
    final parClient = code.maxUsesPerClient == 1
        ? 'une fois par client'
        : '${code.maxUsesPerClient} fois par client';
    final minimum = code.minOrderFcfa == null
        ? ''
        : ' · dès ${CurrencyFormatter.formatFcfa(code.minOrderFcfa!)} d\'achat';
    return '$global · $parClient$minimum';
  }

  static String _window(PromoCode code) {
    final from = code.startsAt;
    final until = code.endsAt;
    if (from != null && until != null) {
      return 'Du ${DateFormatter.formatDate(from)} '
          'au ${DateFormatter.formatDate(until)}';
    }
    if (from != null) return 'À partir du ${DateFormatter.formatDate(from)}';
    return 'Jusqu\'au ${DateFormatter.formatDate(until!)}';
  }
}

/// Ce que le fournisseur vient chercher : quel code, sur quels articles.
class _RedemptionTile extends StatelessWidget {
  const _RedemptionTile({required this.redemption});

  final PromoCodeRedemption redemption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  redemption.clientName,
                  style: theme.textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormatter.formatDate(redemption.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '-${CurrencyFormatter.formatFcfa(redemption.discountFcfa)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final item in redemption.items)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
              child: Text(
                '${item.quantity} × ${item.productName} — '
                '${CurrencyFormatter.formatFcfa(item.unitDiscountFcfa)} / unité',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.code});

  final PromoCode code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final (label, color) = switch (code) {
      _ when !code.isActive => ('Arrêté', scheme.onSurfaceVariant),
      _ when code.maxUses != null && code.usesCount >= code.maxUses! =>
        ('Épuisé', scheme.onSurfaceVariant),
      _ when code.endsAt != null && !now.isBefore(code.endsAt!) =>
        ('Terminé', scheme.onSurfaceVariant),
      _ when code.startsAt != null && now.isBefore(code.startsAt!) =>
        ('Programmé', scheme.tertiary),
      _ => ('En cours', scheme.primary),
    };
    return RoleBadge(label: label, color: color, icon: Icons.circle);
  }
}

class _PromoCodeForm extends ConsumerStatefulWidget {
  const _PromoCodeForm({super.key, required this.onDone, this.existing});

  final VoidCallback onDone;

  /// `null` pour une création. Sinon, le code à corriger.
  final PromoCode? existing;

  @override
  ConsumerState<_PromoCodeForm> createState() => _PromoCodeFormState();
}

class _PromoCodeFormState extends ConsumerState<_PromoCodeForm> {
  late final TextEditingController _code;
  late final TextEditingController _percent;
  late final TextEditingController _label;
  late final TextEditingController _maxUses;
  late final TextEditingController _maxPerClient;
  late final TextEditingController _minOrder;
  DateTime? _endsAt;

  /// Vide = tous les produits. C'est le cas le plus courant, donc le défaut.
  late final Set<String> _productIds;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _code = TextEditingController(text: existing?.code ?? '');
    _percent = TextEditingController(text: '${existing?.percent ?? 10}');
    _label = TextEditingController(text: existing?.label ?? '');
    _maxUses = TextEditingController(
      text: existing?.maxUses == null ? '' : '${existing!.maxUses}',
    );
    _maxPerClient = TextEditingController(
      text: '${existing?.maxUsesPerClient ?? 1}',
    );
    _minOrder = TextEditingController(
      text: existing?.minOrderFcfa == null ? '' : '${existing!.minOrderFcfa}',
    );
    _endsAt = existing?.endsAt;
    _productIds = {...?existing?.productIds};
    _code.addListener(_refresh);
    _percent.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _code.removeListener(_refresh);
    _percent.removeListener(_refresh);
    _code.dispose();
    _percent.dispose();
    _label.dispose();
    _maxUses.dispose();
    _maxPerClient.dispose();
    _minOrder.dispose();
    super.dispose();
  }

  String get _normalizedCode => _code.text.trim().toUpperCase();

  int? get _parsedPercent {
    final value = int.tryParse(_percent.text.trim());
    if (value == null || value < 1 || value > 90) return null;
    return value;
  }

  bool get _canSubmit =>
      _normalizedCode.length >= 3 &&
      _normalizedCode.length <= 24 &&
      !_normalizedCode.contains(' ') &&
      _parsedPercent != null;

  Future<void> _submit() async {
    final controller = ref.read(promoCodeControllerProvider.notifier);
    final ok = _isEditing
        ? await controller.edit(
            id: widget.existing!.id,
            percent: _parsedPercent!,
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
            endsAt: _endsAt,
            maxUses: int.tryParse(_maxUses.text.trim()),
            maxUsesPerClient: int.tryParse(_maxPerClient.text.trim()) ?? 1,
            minOrderFcfa: int.tryParse(_minOrder.text.trim()),
            productIds: _productIds.toList(),
          )
        : await controller.create(
            code: _normalizedCode,
            percent: _parsedPercent!,
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
            endsAt: _endsAt,
            maxUses: int.tryParse(_maxUses.text.trim()),
            maxUsesPerClient: int.tryParse(_maxPerClient.text.trim()) ?? 1,
            minOrderFcfa: int.tryParse(_minOrder.text.trim()),
            productIds: _productIds.toList(),
          );
    if (!mounted) return;
    if (ok) {
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Code $_normalizedCode mis à jour.'
                : 'Code $_normalizedCode créé.',
          ),
        ),
      );
      return;
    }
    final error = ref.read(promoCodeControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          // Le motif vient du serveur (code déjà pris, par exemple) : on
          // l'affiche tel quel plutôt que d'en inventer un.
          messagePourUtilisateur(error, repli: 'Le code n\'a pas pu être créé.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(promoCodeControllerProvider).isLoading;
    final supplierId = ref.watch(operatingSupplierIdProvider);
    final products =
        (supplierId == null
            ? const <Product>[]
            : ref.watch(myProductsProvider(supplierId)).valueOrNull ??
                  const <Product>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nouveau code', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: MtcTextField(
                controller: _code,
                label: 'Code (ex. RENTREE)',
                // Le texte du code ne se modifie pas : il est imprimé sur
                // des affiches, envoyé par message, et
                // `promo_code_redemptions` en garde une copie pour
                // l'historique. Le changer laisserait sans recours tous
                // ceux qui tiennent l'ancien. Tout le reste — pourcentage,
                // dates, plafonds, produits — se corrige.
                enabled: !_isEditing,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MtcTextField(
                controller: _percent,
                label: 'Remise (%)',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        MtcTextField(controller: _label, label: 'Intitulé (facultatif)'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MtcTextField(
                controller: _maxUses,
                label: 'Utilisations max',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MtcTextField(
                controller: _maxPerClient,
                label: 'Par client',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        MtcTextField(
          controller: _minOrder,
          label: 'Achat minimum (FCFA, facultatif)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _endsAt ?? now.add(const Duration(days: 30)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 730)),
            );
            if (picked == null) return;
            // Fin de journée : un code « jusqu'au 15 » doit couvrir le 15.
            setState(() {
              _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
            });
          },
          icon: const Icon(Icons.event_busy_outlined, size: 18),
          label: Text(
            _endsAt == null
                ? 'Expiration : aucune'
                : 'Jusqu\'au ${DateFormatter.formatDate(_endsAt!)}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Un sélecteur avec recherche, et non une liste de pastilles : un
        // fournisseur qui a cent articles ne retrouve pas le bon à l'œil au
        // milieu d'un formulaire.
        ProductMultiPicker(
          products: products,
          selected: _productIds,
          onChanged: (ids) => setState(() {
            _productIds
              ..clear()
              ..addAll(ids);
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        MtcPrimaryButton(
          label: 'Créer le code',
          isLoading: isLoading,
          onPressed: _canSubmit ? _submit : null,
        ),
        TextButton(
          onPressed: isLoading ? null : widget.onDone,
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
