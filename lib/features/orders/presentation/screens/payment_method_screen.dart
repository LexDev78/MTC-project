import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/payment.dart';
import '../providers/checkout_providers.dart';

/// Les trois façons de payer, dans l'ordre des pastilles.
enum _Choix { orange, moov, livraison }

extension on _Choix {
  String get libelle => switch (this) {
    _Choix.orange => MobileMoneyProvider.orangeMoney.label,
    _Choix.moov => MobileMoneyProvider.moovMoney.label,
    _Choix.livraison => 'À la livraison',
  };

  String get icone => switch (this) {
    _Choix.orange || _Choix.moov => ShopIcons.payonline,
    _Choix.livraison => ShopIcons.cash,
  };

  MobileMoneyProvider? get operateur => switch (this) {
    _Choix.orange => MobileMoneyProvider.orangeMoney,
    _Choix.moov => MobileMoneyProvider.moovMoney,
    _Choix.livraison => null,
  };
}

/// Le mode de paiement, d'après les maquettes « Payment method » du kit :
/// des pastilles en haut — Orange Money, Moov Money, à la livraison à la
/// place de la carte, des espèces et du crédit — et en dessous ce que le
/// choix implique. Rien n'est retenu avant « Confirmer ».
class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  late _Choix _choix =
      ref.read(paymentMethodProvider) == PaymentMethod.onDelivery
      ? _Choix.livraison
      : (ref.read(preferredMobileMoneyProvider) == MobileMoneyProvider.moovMoney
            ? _Choix.moov
            : _Choix.orange);

  /// Une clé par pastille : la rangée dépasse l'écran, et la pastille
  /// choisie doit être visible à l'ouverture (« À la livraison », le choix
  /// par défaut, est la dernière).
  final _cles = {for (final choix in _Choix.values) choix: GlobalKey()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexte = _cles[_choix]?.currentContext;
      if (contexte != null && contexte.mounted) {
        Scrollable.ensureVisible(contexte, alignment: 0.5);
      }
    });
  }

  void _confirmer() {
    final operateur = _choix.operateur;
    if (operateur == null) {
      ref.read(paymentMethodProvider.notifier).state = PaymentMethod.onDelivery;
      // Quitter « maintenant » annule un paiement simulé déjà fait : y
      // revenir le redemandera.
      ref.read(mobileMoneyProviderChoiceProvider.notifier).state = null;
    } else {
      ref.read(paymentMethodProvider.notifier).state = PaymentMethod.now;
      ref.read(preferredMobileMoneyProvider.notifier).state = operateur;
      // Un paiement fait chez l'autre opérateur ne vaut pas pour celui-ci.
      if (ref.read(mobileMoneyProviderChoiceProvider) != operateur) {
        ref.read(mobileMoneyProviderChoiceProvider.notifier).state = null;
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final operateur = _choix.operateur;
    return Scaffold(
      appBar: AppBar(title: const Text('Mode de paiement')),
      body: Column(
        children: [
          const SizedBox(height: ShopSizes.padding / 2),
          ShopPillRow(
            padding: ShopSizes.screenMargin,
            children: [
              for (final choix in _Choix.values)
                ShopPill(
                  key: _cles[choix],
                  label: choix.libelle,
                  icon: choix.icone,
                  large: true,
                  active: choix == _choix,
                  onTap: () => setState(() => _choix = choix),
                ),
            ],
          ),
          Expanded(
            child: operateur == null
                ? const IllustratedMessage(
                    illustration: ShopIllustration.payOnDelivery,
                    title: 'Payer à la livraison',
                    message:
                        'Vous réglez à la réception, en espèces ou par Mobile '
                        'Money, auprès du livreur ou au point de livraison.',
                  )
                : _MobileMoney(operateur: operateur),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Confirmer',
        onPressed: _confirmer,
      ),
    );
  }
}

/// Le paiement par un opérateur : ce qui se passera à la confirmation.
class _MobileMoney extends StatelessWidget {
  const _MobileMoney({required this.operateur});

  final MobileMoneyProvider operateur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = operateur == MobileMoneyProvider.orangeMoney
        ? const Color(0xFFFF6600)
        : const Color(0xFF0072CE);
    return ListView(
      padding: const EdgeInsets.all(ShopSizes.screenMargin),
      children: [
        Container(
          padding: const EdgeInsets.all(ShopSizes.padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShopSizes.radius),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: couleur,
                    child: const ShopIcon(
                      ShopIcons.payonline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: ShopSizes.padding * 0.75),
                  Expanded(
                    child: Text(
                      'Payer avec ${operateur.label}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ShopSizes.padding),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ShopSizes.padding),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(ShopSizes.radius),
                ),
                child: Text(
                  'Le paiement vous sera demandé quand vous confirmerez la '
                  'commande. Gardez votre téléphone à portée de main.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
