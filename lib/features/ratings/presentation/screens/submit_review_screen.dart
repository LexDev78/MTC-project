import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';

import '../controllers/review_controller.dart';
import '../providers/review_providers.dart';
import '../widgets/star_rating_input.dart';

class SubmitReviewScreen extends ConsumerWidget {
  const SubmitReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Laisser un avis')),
      body: AsyncValueWidget(
        value: orderAsync,
        data: (order) {
          final group = order.supplierGroups.firstWhere(
            (g) => g.status == OrderStatus.delivered,
            orElse: () => order.supplierGroups.first,
          );
          final canReviewAsync = ref.watch(
            canReviewProvider((orderId: orderId, groupId: group.id)),
          );

          return AsyncValueWidget(
            value: canReviewAsync,
            data: (canReview) {
              if (!canReview) {
                return const MtcEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Vous avez déjà noté cette commande',
                );
              }
              return _ReviewForm(
                orderId: orderId,
                supplierGroupId: group.id,
                supplierId: group.supplierId,
                supplierName: group.supplierName,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.orderId,
    required this.supplierGroupId,
    required this.supplierId,
    required this.supplierName,
  });

  final String orderId;
  final String supplierGroupId;
  final String supplierId;
  final String supplierName;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  int _stars = 5;
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(reviewControllerProvider.notifier)
        .submit(
          orderId: widget.orderId,
          supplierGroupId: widget.supplierGroupId,
          supplierId: widget.supplierId,
          stars: _stars,
          comment: _commentController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Une erreur est survenue')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.supplierName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            StarRatingInput(
              value: _stars,
              onChanged: (value) => setState(() => _stars = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcTextField(
              label: 'Votre commentaire',
              controller: _commentController,
              validator: Validators.required,
            ),
            const SizedBox(height: AppSpacing.xl),
            MtcPrimaryButton(
              label: "Envoyer l'avis",
              isLoading: reviewState.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
