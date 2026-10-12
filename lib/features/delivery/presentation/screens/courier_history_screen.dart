import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/courier_delivery.dart';
import '../../domain/entities/courier_history.dart';
import '../providers/courier_history_providers.dart';

/// Ce que le livreur a fait, et ce qu'on en a pensé.
///
/// Deux onglets volontairement séparés : ses courses et ses notes répondent
/// à deux questions différentes (« combien ai-je gagné ce mois-ci ? » et
/// « qu'est-ce qu'on me reproche ? »), et les mêler produirait une liste où
/// aucune des deux ne se lit.
///
/// Aucune identité n'y apparaît : ni nom de client, ni téléphone, ni adresse,
/// ni nom de fournisseur. Ce n'est pas un choix d'affichage — la lecture
/// (`fetch_courier_delivery_history`, `0060`) ne les ramène pas.
class CourierHistoryScreen extends ConsumerWidget {
  const CourierHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mon activité'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Courses'),
              Tab(text: 'Notes reçues'),
            ],
          ),
        ),
        body: const Column(
          children: [
            _StatsHeader(),
            Expanded(
              child: TabBarView(
                children: [_HistoryTab(), _RatingsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bandeau de cumuls, au-dessus des deux onglets : c'est la première
/// chose qu'un livreur regarde, et elle vaut pour les deux listes.
class _StatsHeader extends ConsumerWidget {
  const _StatsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(courierStatsProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    if (stats == null) {
      // Pas d'indicateur de chargement ici : le bandeau ferait sauter la
      // liste en apparaissant. Il arrive simplement quand il est prêt.
      return const SizedBox(height: AppSpacing.md);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _StatTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Livrées',
            value: '${stats.deliveredCount}',
            detail: '${stats.monthDeliveredCount} ce mois',
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatTile(
            icon: Icons.payments_outlined,
            label: 'Frais perçus',
            value: CurrencyFormatter.formatFcfa(stats.deliveredFeesFcfa),
            detail:
                '${CurrencyFormatter.formatFcfa(stats.monthFeesFcfa)} ce mois',
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatTile(
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            label: 'Note',
            // Zéro note n'est pas « 0 sur 5 » : le dire ainsi ferait croire
            // à un mauvais livreur là où il n'y a encore rien.
            value: stats.ratingCount == 0
                ? '—'
                : stats.ratingAverage.toStringAsFixed(1),
            detail: stats.ratingCount == 0
                ? 'pas encore notée'
                : '${stats.ratingCount} avis',
            detailColor: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.iconColor,
    this.detailColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color? iconColor;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: iconColor ?? scheme.primary),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: detailColor ?? scheme.onSurfaceVariant,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(courierHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courierHistoryProvider);
        ref.invalidate(courierStatsProvider);
        await ref.read(courierHistoryProvider.future);
      },
      child: AsyncValueWidget(
        value: historyAsync,
        data: (entries) {
          if (entries.isEmpty) {
            return const _EmptyScroll(
              icon: Icons.history_rounded,
              title: 'Aucune course terminée',
              subtitle:
                  'Vos courses livrées apparaîtront ici, avec les frais perçus '
                  'et la note reçue.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: _HistoryCard(entry: entries[index]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final CourierHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final cancelled = entry.status == DeliveryStatus.cancelled;
    final date = entry.happenedAt;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  cancelled
                      ? Icons.cancel_outlined
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: cancelled ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${entry.pickupCity} → ${entry.dropoffCity}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  date == null ? '' : DateFormatter.formatDate(date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${entry.itemCount} article${entry.itemCount > 1 ? 's' : ''} · '
              'réf. ${entry.reference}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  cancelled
                      ? 'Annulée'
                      : CurrencyFormatter.formatFcfa(entry.deliveryFeeFcfa),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cancelled ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (entry.clientStars != null)
                  _StarsChip(
                    label: 'Client',
                    stars: entry.clientStars!,
                  ),
                if (entry.supplierStars != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _StarsChip(
                    label: 'Fournisseur',
                    stars: entry.supplierStars!,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// « Client 4★ » : d'où vient la note et combien — sans qui l'a mise.
class _StarsChip extends StatelessWidget {
  const _StarsChip({required this.label, required this.stars});

  final String label;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
          Text('$stars', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RatingsTab extends ConsumerWidget {
  const _RatingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(courierRatingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courierRatingsProvider);
        ref.invalidate(courierStatsProvider);
        await ref.read(courierRatingsProvider.future);
      },
      child: AsyncValueWidget(
        value: ratingsAsync,
        data: (ratings) {
          if (ratings.isEmpty) {
            return const _EmptyScroll(
              icon: Icons.star_border_rounded,
              title: 'Aucune note pour l\'instant',
              subtitle:
                  'Après chaque livraison, le client et le fournisseur peuvent '
                  'vous noter. Leurs commentaires apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: ratings.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final rating = ratings[index];
              return FadeSlideIn(
                index: index,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MtcRatingStars(
                              rating: rating.stars.toDouble(),
                              showValue: false,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              rating.raterRole.label,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const Spacer(),
                            Text(
                              DateFormatter.formatDate(rating.createdAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (rating.comment != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(rating.comment!),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// État vide qui reste tirable vers le bas : sans défilement, le
/// `RefreshIndicator` ne se déclenche pas et l'écran paraît figé.
class _EmptyScroll extends StatelessWidget {
  const _EmptyScroll({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        MtcEmptyState(icon: icon, title: title, subtitle: subtitle),
      ],
    );
  }
}
