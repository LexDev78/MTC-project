import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';

import '../../domain/order_reference.dart';
import '../../domain/order_status_transitions.dart';
import '../controllers/order_controller.dart';
import '../providers/order_providers.dart';
import '../widgets/order_cards.dart';

/// Les raisons proposées, dans l'ordre de la maquette : la plus fréquente
/// d'abord, « Autre » à la fin, avec sa précision.
enum _Motif {
  erreur('Je me suis trompé d\'article ou de quantité'),
  delai('Le délai de livraison est trop long'),
  prix('J\'ai trouvé moins cher ailleurs'),
  besoin('Je n\'en ai plus besoin'),
  autre('Autre raison');

  const _Motif(this.libelle);

  final String libelle;
}

/// Annuler la part d'une boutique (maquette « Cancel order » du kit) : la
/// commande en carte, la raison à choisir, et le bouton rouge.
///
/// Une commande MTC se découpe par boutique : c'est la part de l'une d'elles
/// qu'on annule ici, tant qu'elle ne l'a pas confirmée (`canClientCancel`,
/// revérifié en base). Le bouton rouge est la confirmation : la raison
/// choisie part avec l'annulation, et la boutique la lira.
class OrderCancelScreen extends ConsumerStatefulWidget {
  const OrderCancelScreen({
    super.key,
    required this.orderId,
    required this.groupId,
  });

  final String orderId;
  final String groupId;

  @override
  ConsumerState<OrderCancelScreen> createState() => _OrderCancelScreenState();
}

class _OrderCancelScreenState extends ConsumerState<OrderCancelScreen> {
  _Motif? _motif;
  final _precision = TextEditingController();

  @override
  void dispose() {
    _precision.dispose();
    super.dispose();
  }

  String? get _raison {
    final motif = _motif;
    if (motif == null) return null;
    if (motif != _Motif.autre) return motif.libelle;
    final precision = _precision.text.trim();
    return precision.isEmpty ? motif.libelle : precision;
  }

  Future<void> _annuler(String boutique) async {
    final messager = ScaffoldMessenger.of(context);
    final routeur = GoRouter.of(context);
    final ok = await ref
        .read(orderControllerProvider.notifier)
        .cancel(
          orderId: widget.orderId,
          groupId: widget.groupId,
          reason: _raison,
        );
    if (!mounted) return;
    if (ok) {
      // Ouvert depuis la fiche, on y revient. Ouvert seul (un lien), il n'y
      // a rien dessous : retirer la page laisserait un écran vide.
      if (routeur.canPop()) {
        routeur.pop();
      } else {
        routeur.go(AppRoutes.orderDetail(widget.orderId));
      }
      messager.showSnackBar(
        SnackBar(content: Text('Votre commande chez $boutique est annulée.')),
      );
      return;
    }
    messager.showSnackBar(
      SnackBar(
        content: Text(
          messagePourUtilisateur(
            ref.read(orderControllerProvider).error,
            repli: 'La commande n\'a pas pu être annulée.',
          ),
        ),
      ),
    );
  }

  /// Le « i » de la maquette : la règle, avant qu'on la découvre en
  /// essayant.
  Future<void> _expliquer(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quand annuler ?'),
      content: const Text(
        'Vous pouvez annuler tant que la boutique n\'a pas confirmé votre '
        'commande. Ensuite, seule la boutique peut l\'annuler : écrivez-lui.'
        '\n\n'
        'Une commande passée chez plusieurs boutiques s\'annule boutique par '
        'boutique. Les autres parts continuent leur chemin.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Compris'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commande = ref.watch(orderDetailProvider(widget.orderId));
    final enCours = ref.watch(orderControllerProvider).isLoading;
    final valeur = commande.valueOrNull;
    final groupe = valeur?.supplierGroups.firstWhereOrNull(
      (g) => g.id == widget.groupId,
    );
    final annulable = groupe != null && canClientCancel(groupe.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annuler la commande'),
        actions: [
          IconButton(
            tooltip: 'Quand annuler ?',
            onPressed: () => _expliquer(context),
            icon: const ShopIcon(ShopIcons.info),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: commande.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: CircularProgressIndicator(color: ShopColors.primary),
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'La commande n\'a pas pu être chargée',
          message: messagePourUtilisateur(erreur),
        ),
        data: (commande) {
          if (groupe == null) {
            return const IllustratedMessage(
              illustration: ShopIllustration.noResult,
              title: 'Commande introuvable',
              message: 'Cette part de commande n\'existe plus.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              OrderStatusCard(
                reference: commande.reference,
                placedOn: DateFormatter.formatDayMonthYear(commande.placedAt),
                steps: orderSteps(groupe.status),
                items: [
                  for (final article in groupe.items)
                    OrderItemLine(item: article, boutique: groupe.supplierName),
                ],
              ),
              const SizedBox(height: ShopSizes.padding * 1.5),
              if (!annulable)
                Text(
                  // Confirmée entre-temps : seule la boutique peut encore
                  // l'annuler, il faut s'adresser à elle.
                  '${groupe.supplierName} a déjà confirmé cette commande : '
                  'elle ne peut plus être annulée d\'ici. Écrivez à la '
                  'boutique si vous ne la voulez plus.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: ShopColors.error,
                    height: 1.4,
                  ),
                )
              else ...[
                Text(
                  'Pourquoi voulez-vous annuler ?',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                for (final motif in _Motif.values)
                  ShopRadioTile<_Motif>(
                    title: motif.libelle,
                    value: motif,
                    groupValue: _motif,
                    square: true,
                    onChanged: (choisi) => setState(() => _motif = choisi),
                  ),
                if (_motif == _Motif.autre) ...[
                  const SizedBox(height: ShopSizes.padding),
                  TextField(
                    controller: _precision,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Dites-nous en un mot (facultatif)',
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: groupe == null || !annulable
          ? null
          : BottomActionBar(
              label: 'Annuler la commande',
              color: ShopColors.error,
              isLoading: enCours,
              // Sans raison, l'annulation part quand même côté serveur, mais
              // la maquette la demande : la boutique y gagne une explication.
              onPressed: _motif == null
                  ? null
                  : () => _annuler(groupe.supplierName),
            ),
    );
  }
}
