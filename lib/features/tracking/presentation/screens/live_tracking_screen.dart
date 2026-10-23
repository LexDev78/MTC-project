import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../providers/tracking_providers.dart';
import '../widgets/eta_banner.dart';
import '../widgets/tracking_map.dart';

class LiveTrackingScreen extends ConsumerWidget {
  const LiveTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(trackingParamsProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de livraison')),
      body: params.when(
        skipLoadingOnReload: true,
        loading: () => const _Chargement(),
        error: (erreur, _) => _Erreur(
          erreur: erreur,
          onRetry: () => ref.invalidate(trackingParamsProvider(orderId)),
        ),
        data: (params) {
          // Livraison assurée par le fournisseur lui-même : personne ne
          // transmet de position. Le dire franchement vaut mieux que laisser
          // tourner un chargement qui n'aboutira jamais — et mieux encore
          // qu'animer un livreur imaginaire.
          if (!params.isMtcDelivery) {
            return const IllustratedMessage(
              illustration: ShopIllustration.help,
              title: 'Suivi indisponible',
              message:
                  'Cette commande est livrée directement par la boutique. '
                  'Écrivez-lui pour savoir où en est votre colis.',
            );
          }
          return ref
              .watch(trackingStreamProvider(orderId))
              .when(
                skipLoadingOnReload: true,
                loading: () => const _Chargement(),
                error: (erreur, _) => _Erreur(
                  erreur: erreur,
                  onRetry: () =>
                      ref.invalidate(trackingStreamProvider(orderId)),
                ),
                data: (tracking) => Column(
                  children: [
                    EtaBanner(tracking: tracking),
                    Expanded(child: TrackingMap(tracking: tracking)),
                  ],
                ),
              );
        },
      ),
    );
  }
}

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: ShopColors.primary));
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.erreur, required this.onRetry});

  final Object erreur;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => IllustratedMessage(
    illustration: ShopIllustration.serverError,
    title: 'Le suivi n\'a pas pu être chargé',
    message: messagePourUtilisateur(erreur),
    action: OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
  );
}
