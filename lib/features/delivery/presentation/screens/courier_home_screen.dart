import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';

import '../../domain/entities/courier_delivery.dart';
import '../controllers/courier_controller.dart';
import '../providers/courier_position_provider.dart';
import '../providers/delivery_providers.dart';

/// Écran d'accueil du livreur : sa prise de service, la course en cours, et
/// celles qui lui sont proposées.
class CourierHomeScreen extends ConsumerStatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  ConsumerState<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends ConsumerState<CourierHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Les courses laissées sans réponse repartent au livreur suivant quand
    // quelqu'un ouvre sa liste : c'est ce qui tient lieu de planificateur,
    // plutôt qu'un `pg_cron` pour une relance que la première ouverture
    // d'app couvre déjà.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(courierControllerProvider.notifier).reofferExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final courier = ref.watch(currentCourierProvider);
    final deliveriesAsync = ref.watch(courierDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: courier == null
          ? const MtcLoadingView()
          : !courier.canTakeDeliveries
          ? _PendingApproval(status: courier.courierStatus)
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(courierControllerProvider.notifier).reofferExpired(),
              child: AsyncValueWidget(
                value: deliveriesAsync,
                data: (_) {
                  final active = ref.watch(activeDeliveryProvider);
                  final offered = ref.watch(offeredDeliveriesProvider);

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _OnlineSwitch(courier: courier),
                      const _PositionNotice(),
                      const SizedBox(height: AppSpacing.lg),
                      if (active != null) ...[
                        Text(
                          'Course en cours',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _DeliveryCard(delivery: active),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Text(
                        'Propositions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (offered.isEmpty)
                        const MtcEmptyState(
                          icon: Icons.inbox_rounded,
                          title: 'Aucune course proposée',
                          subtitle:
                              'Restez en ligne : la prochaine course du secteur '
                              'vous sera proposée en premier si vous êtes le plus proche.',
                        )
                      else
                        for (final delivery in offered) ...[
                          _DeliveryCard(delivery: delivery),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// Dossier pas encore validé : aucune course ne sera proposée, l'écran le dit
/// au lieu d'afficher une liste vide qu'on croirait due au hasard.
class _PendingApproval extends StatelessWidget {
  const _PendingApproval({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: MtcEmptyState(
          icon: status == CourierStatus.rejected
              ? Icons.cancel_outlined
              : Icons.hourglass_top_rounded,
          title: status.label,
          subtitle: switch (status) {
            CourierStatus.pending =>
              'Un agent MTC examine votre inscription. Vous recevrez une '
                  'notification dès qu\'elle sera validée.',
            CourierStatus.rejected =>
              'Votre inscription n\'a pas été retenue. Contactez MTC pour en '
                  'connaître la raison.',
            CourierStatus.suspended =>
              'Votre compte est suspendu. Contactez MTC.',
            CourierStatus.approved => '',
          },
        ),
      ),
    );
  }
}

class _OnlineSwitch extends ConsumerWidget {
  const _OnlineSwitch({required this.courier});

  final CourierUser courier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(courierControllerProvider).isLoading;

    return Card(
      child: SwitchListTile(
        value: courier.isOnline,
        onChanged: isLoading
            ? null
            : (value) =>
                  ref.read(courierControllerProvider.notifier).setOnline(value),
        title: Text(courier.isOnline ? 'En service' : 'Hors service'),
        subtitle: Text(
          courier.isOnline
              ? 'Vous recevez les courses de ${courier.city}.'
              : 'Activez pour recevoir des courses.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        secondary: Icon(
          courier.isOnline
              ? Icons.delivery_dining_rounded
              : Icons.pause_circle_outline_rounded,
          color: courier.isOnline ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Prévient quand le livreur est en service sans position transmise.
///
/// Ce n'est pas un détail d'affichage : sans position, il n'est pas
/// classable et `offer_delivery_to_next_courier` ne lui proposera **aucune**
/// course. Sans ce message, il attendrait indéfiniment une proposition qui
/// ne peut pas arriver, en croyant qu'il n'y a simplement rien à livrer.
class _PositionNotice extends ConsumerWidget {
  const _PositionNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courier = ref.watch(currentCourierProvider);
    final position = ref.watch(courierPositionProvider);
    if (courier == null || !courier.isOnline) return const SizedBox.shrink();
    if (position.valueOrNull != null) return const SizedBox.shrink();
    // En cours d'acquisition : pas d'alarme pour une seconde d'attente.
    if (position.isLoading) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.location_off_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Position indisponible. Activez la localisation : sans elle, '
                  'aucune course ne peut vous être proposée.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryCard extends ConsumerWidget {
  const _DeliveryCard({required this.delivery});

  final CourierDelivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pieces = delivery.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => context.push(AppRoutes.courierDeliveryPath(delivery.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      delivery.supplierName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Chip(
                    label: Text(delivery.status.label),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$pieces article${pieces > 1 ? 's' : ''} · '
                '${delivery.supplierCity} → ${delivery.deliveryCity}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Frais de livraison : '
                '${CurrencyFormatter.formatFcfa(delivery.deliveryFeeFcfa)}',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (delivery.collectOnDelivery)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'À encaisser : '
                    '${CurrencyFormatter.formatFcfa(delivery.subtotalFcfa + delivery.deliveryFeeFcfa)}',
                    style: TextStyle(color: scheme.tertiary),
                  ),
                ),
              if (delivery.status == DeliveryStatus.offered) ...[
                const SizedBox(height: AppSpacing.sm),
                _OfferActions(delivery: delivery),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferActions extends ConsumerWidget {
  const _OfferActions({required this.delivery});

  final CourierDelivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(courierControllerProvider.notifier);
    final isLoading = ref.watch(courierControllerProvider).isLoading;

    Future<void> run(Future<bool> Function() action) async {
      final ok = await action();
      if (!context.mounted || ok) return;
      // Le motif vient du serveur (course déjà prise, fenêtre passée) : on
      // l'affiche tel quel plutôt que d'en inventer un.
      final error = ref.read(courierControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error?.toString() ?? 'Cette course n\'est plus disponible.',
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () => run(() => controller.decline(delivery.id)),
            child: const Text('Refuser'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: MtcPrimaryButton(
            label: 'Accepter la course',
            isLoading: isLoading,
            onPressed: () => run(() => controller.accept(delivery.id)),
          ),
        ),
      ],
    );
  }
}
