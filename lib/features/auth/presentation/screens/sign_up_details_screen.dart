import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/user_role.dart';
import '../controllers/auth_controller.dart';

/// What `RoleSelectionScreen` (client) or `SupplierLegalTypeScreen` (tiers
/// supplier) hands off as this route's `extra`. [legalType] is only set for
/// [UserRole.supplierTiers] — a client sign-up has no legal form to choose.
typedef SignUpDetailsArgs = ({UserRole role, SupplierLegalType? legalType});

class SignUpDetailsScreen extends ConsumerStatefulWidget {
  const SignUpDetailsScreen({super.key, required this.args});

  final SignUpDetailsArgs args;

  @override
  ConsumerState<SignUpDetailsScreen> createState() =>
      _SignUpDetailsScreenState();
}

class _SignUpDetailsScreenState extends ConsumerState<SignUpDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _cityController = TextEditingController();

  bool get _isSupplier => widget.args.role == UserRole.supplierTiers;
  bool get _isCompany => widget.args.legalType == SupplierLegalType.company;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);

    final success = _isSupplier
        ? await controller.signUpSupplierTiers(
            displayName: _displayNameController.text.trim(),
            usernameOrPhone: _usernameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            password: _passwordController.text,
            businessName: _businessNameController.text.trim(),
            city: _cityController.text.trim(),
            legalType: widget.args.legalType!,
          )
        : await controller.signUpClient(
            displayName: _displayNameController.text.trim(),
            usernameOrPhone: _usernameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            password: _passwordController.text,
          );

    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          !_isSupplier
              ? 'Compte client'
              : (_isCompany ? 'Compte société' : 'Compte vendeur individuel'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MtcTextField(
                  label: 'Nom complet',
                  controller: _displayNameController,
                  validator: Validators.required,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_isSupplier) ...[
                  MtcTextField(
                    label: _isCompany ? 'Nom de la société' : 'Nom de la boutique',
                    controller: _businessNameController,
                    validator: Validators.required,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MtcTextField(
                    label: 'Ville',
                    controller: _cityController,
                    validator: Validators.required,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                MtcTextField(
                  label: "Nom d'utilisateur",
                  controller: _usernameController,
                  validator: Validators.usernameOrPhone,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Numéro de téléphone',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Mot de passe',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                ),
                if (_isSupplier) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _VerificationNotice(),
                ],
                const SizedBox(height: AppSpacing.xl),
                MtcPrimaryButton(
                  label: 'Créer mon compte',
                  isLoading: authState.isLoading,
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

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Votre identité sera vérifiée avant que vos produits soient visibles par les clients.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
