import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';
import 'misc.dart';

/// L'état d'une étape du suivi de commande (`OrderProcessStatus` du kit).
enum OrderStepState { done, processing, notDoneYet, canceled }

/// Une étape : son libellé et son état.
class OrderStep {
  const OrderStep(this.label, this.state);

  final String label;
  final OrderStepState state;
}

/// Le suivi en points reliés (`OrderProgress` du kit) : vert pour ce qui
/// est fait, cercle animé pour l'étape en cours, gris pour la suite, rouge
/// pour une annulation.
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.steps});

  final List<OrderStep> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: _Etape(
              step: steps[i],
              lineLeft: i == 0 ? null : steps[i].state,
              lineRight: i == steps.length - 1 ? null : steps[i + 1].state,
            ),
          ),
      ],
    );
  }
}

class _Etape extends StatelessWidget {
  const _Etape({required this.step, this.lineLeft, this.lineRight});

  final OrderStep step;
  final OrderStepState? lineLeft, lineRight;

  Color _trait(BuildContext context, OrderStepState state) => switch (state) {
    OrderStepState.notDoneYet => Theme.of(context).dividerColor,
    OrderStepState.canceled => ShopColors.error,
    _ => ShopColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif =
        step.state == OrderStepState.processing ||
        step.state == OrderStepState.canceled;
    return Column(
      children: [
        Text(
          step.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: actif
                ? theme.colorScheme.onSurface
                : theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: ShopSizes.padding / 2),
        Row(
          children: [
            Expanded(
              child: lineLeft == null
                  ? const SizedBox()
                  : Container(height: 2, color: _trait(context, lineLeft!)),
            ),
            _Point(step.state),
            Expanded(
              child: lineRight == null
                  ? const SizedBox()
                  : Container(height: 2, color: _trait(context, lineRight!)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.state);

  final OrderStepState state;

  @override
  Widget build(BuildContext context) {
    final fond = Theme.of(context).scaffoldBackgroundColor;
    return switch (state) {
      OrderStepState.done => CircleAvatar(
        radius: 12,
        backgroundColor: ShopColors.success,
        child: Icon(Icons.done, size: 12, color: fond),
      ),
      OrderStepState.processing => CircleAvatar(
        radius: 12,
        backgroundColor: ShopColors.success,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(
            value: 0.75,
            color: fond,
            strokeWidth: 2,
          ),
        ),
      ),
      OrderStepState.notDoneYet => CircleAvatar(
        radius: 12,
        backgroundColor: Theme.of(context).dividerColor,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(backgroundColor: fond),
        ),
      ),
      OrderStepState.canceled => CircleAvatar(
        radius: 12,
        backgroundColor: ShopColors.error,
        child: Icon(Icons.close, size: 12, color: fond),
      ),
    };
  }
}

/// La carte d'une commande (`OrderStatusCard` du kit) : numéro et date,
/// chevron, suivi en points, puis les articles.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({
    super.key,
    required this.reference,
    required this.placedOn,
    required this.steps,
    this.items = const [],
    this.onTap,
  });

  final String reference;
  final String placedOn;
  final List<OrderStep> steps;

  /// Les articles, séparés par un trait.
  final List<Widget> items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        side: BorderSide(color: theme.dividerColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      // Toute la carte s'ouvre, comme dans le kit (`press` sur la carte
      // entière) : on touche l'article autant que l'en-tête.
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande $reference',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: ShopSizes.padding / 2),
                        Text(
                          'Passée le $placedOn',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    ShopIcon(
                      ShopIcons.miniRight,
                      color: theme.iconTheme.color?.withValues(alpha: 0.3),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
              child: OrderProgress(steps: steps),
            ),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: ShopSizes.padding),
                  child: Divider(height: ShopSizes.padding * 2),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShopSizes.padding,
                ),
                child: items[i],
              ),
            ],
            if (items.isNotEmpty) const SizedBox(height: ShopSizes.padding),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de l'historique des commandes (maquette « Orders ») : icône,
/// statut, compteur en pastille colorée, chevron.
class StatusCountTile extends StatelessWidget {
  const StatusCountTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  final String icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChevronStatusRow(
      icon: icon,
      label: label,
      onTap: onTap,
      trailing: CountPill(count: count, color: color),
    );
  }
}

/// La ligne commune de [StatusCountTile] : plus grande qu'une ligne de
/// menu (texte 16), avec un compteur avant le chevron.
class ChevronStatusRow extends StatelessWidget {
  const ChevronStatusRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final String icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
            child: Row(
              children: [
                ShopIcon(icon),
                const SizedBox(width: ShopSizes.padding),
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                trailing,
                const SizedBox(width: ShopSizes.padding / 2),
                ShopIcon(
                  ShopIcons.miniRight,
                  color: theme.iconTheme.color?.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Une ligne de récapitulatif : libellé gris, montant à droite.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Le total : libellé et montant en noir.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gris = theme.textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding / 4),
      // La valeur prend au plus 60 % de la ligne, et passe à la ligne
      // au-delà : un « À l'étape suivante » avec un texte agrandi débordait.
      child: LayoutBuilder(
        builder: (context, contraintes) => Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: emphasized ? theme.colorScheme.onSurface : gris,
                ),
              ),
            ),
            const SizedBox(width: ShopSizes.padding / 2),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contraintes.maxWidth * 0.6),
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: valueColor ?? theme.colorScheme.onSurface,
                  fontWeight: emphasized ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le récapitulatif en carte cerclée (« Récapitulatif de la commande ») :
/// les lignes, un trait, puis les totaux.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    this.title = 'Récapitulatif',
    required this.rows,
    this.totals = const [],
  });

  final String title;
  final List<Widget> rows;
  final List<Widget> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        border: Border.all(color: theme.dividerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(ShopSizes.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: ShopSizes.padding / 2),
                ...rows,
              ],
            ),
          ),
          if (totals.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: Column(children: totals),
            ),
          ],
        ],
      ),
    );
  }
}
