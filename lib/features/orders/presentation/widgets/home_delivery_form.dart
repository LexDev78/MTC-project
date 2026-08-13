import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/checkout_providers.dart';
import 'supplier_message_field.dart';

/// Extra fields for the "home delivery" fulfillment path — phone (plus an
/// optional second contact number), a note for the supplier (text or
/// voice), an optional paid priority flag, and a delivery date/time-slot
/// pick. The delivery address itself stays on `CheckoutScreen`'s existing
/// address card, reused as-is above this form.
class HomeDeliveryForm extends ConsumerWidget {
  const HomeDeliveryForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(courierPhoneProvider);
    final alternatePhone = ref.watch(alternatePhoneProvider);
    final isPriority = ref.watch(isPriorityOrderProvider);
    final dateOptions = ref.watch(deliveryDateOptionsProvider);
    final selectedDate = ref.watch(selectedDeliveryDateProvider);
    final selectedSlot = ref.watch(selectedDeliveryTimeSlotProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditableRow(
              icon: Icons.phone_outlined,
              label: phone.isEmpty ? 'Téléphone' : phone,
              onTap: () => _editPhone(context, ref, phone),
            ),
            if (alternatePhone == null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: TextButton.icon(
                  onPressed: () => _editAlternatePhone(context, ref, ''),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ajouter un autre numéro'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _EditableRow(
                      icon: Icons.phone_outlined,
                      label: alternatePhone,
                      onTap: () =>
                          _editAlternatePhone(context, ref, alternatePhone),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Retirer ce numéro',
                    onPressed: () =>
                        ref.read(alternatePhoneProvider.notifier).state = null,
                  ),
                ],
              ),
            const Divider(),
            const SupplierMessageField(),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isPriority,
              onChanged: (value) =>
                  ref.read(isPriorityOrderProvider.notifier).state = value,
              title: const Text('Commande prioritaire'),
              subtitle: const Text(
                'Traitement accéléré (+$priorityOrderFeeFcfa FCFA)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Créneau de livraison', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final date in dateOptions)
                  ChoiceChip(
                    label: Text(
                      '${DateFormatter.formatDayMonth(date)}, ${DateFormatter.weekdayShort(date)}',
                    ),
                    selected: DateUtils.isSameDay(date, selectedDate),
                    onSelected: (_) =>
                        ref.read(selectedDeliveryDateProvider.notifier).state =
                            date,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final slot in deliveryTimeSlotOptions)
                  ChoiceChip(
                    label: Text(slot),
                    selected: slot == selectedSlot,
                    onSelected: (_) =>
                        ref
                                .read(selectedDeliveryTimeSlotProvider.notifier)
                                .state =
                            slot,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPhone(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final result = await _showEditDialog(
      context,
      title: 'Téléphone du livreur',
      initialValue: current,
      keyboardType: TextInputType.phone,
      validator: Validators.phone,
    );
    if (result != null) {
      ref.read(courierPhoneProvider.notifier).state = result;
    }
  }

  Future<void> _editAlternatePhone(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final result = await _showEditDialog(
      context,
      title: 'Autre numéro de téléphone',
      initialValue: current,
      keyboardType: TextInputType.phone,
      validator: Validators.phone,
    );
    if (result != null) {
      ref.read(alternatePhoneProvider.notifier).state = result;
    }
  }

  Future<String?> _showEditDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: MtcTextField(
            label: title,
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? true) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
