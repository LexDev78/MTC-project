import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../providers/review_providers.dart';

/// « Laisser un avis », ou la preuve qu'il est publié.
///
/// Le bouton restait affiché après l'envoi : rien ne confirmait au client
/// que son avis avait été enregistré, et le rouvrir laissait croire qu'il
/// fallait recommencer. Une fois l'avis publié, la commande le dit.
class ReviewEntry extends ConsumerWidget {
  const ReviewEntry({super.key, required this.orderId, required this.groupId});

  final String orderId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview = ref
        .watch(canReviewProvider((orderId: orderId, groupId: groupId)))
        .valueOrNull;

    if (canReview == false) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding / 2),
        child: Row(
          children: [
            const CheckMark(radius: 10, color: ShopColors.success),
            const SizedBox(width: ShopSizes.padding / 2),
            Expanded(
              child: Text(
                'Avis publié. Merci !',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ShopColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () =>
          context.push(AppRoutes.orderReview(orderId, groupId: groupId)),
      icon: const ShopIcon(ShopIcons.star, size: 20),
      label: const Text('Laisser un avis'),
    );
  }
}
