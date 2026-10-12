import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart'
    show ChatProductAttachment;
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/ratings/presentation/widgets/product_reviews_section.dart';
import 'package:mtc_app/features/comments/presentation/widgets/product_comments_modal.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/promotion_pricing.dart';
import '../providers/catalog_providers.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/promotion_badge.dart';
import '../widgets/variant_video_player.dart';
import '../widgets/product_card.dart'
    show ProductCard, ProductCategoryIcon, ProductImage;

/// The quantity picked on the detail page, isolated per product so
/// backgrounding one product's screen never leaks its quantity into
/// another's — shared between the inline stepper (next to the price) and
/// the bottom action bar so both stay in sync without threading state
/// through the widget tree.
final _selectedQuantityProvider = StateProvider.autoDispose.family<int, String>(
  (ref, productId) => 1,
);

/// The variant currently picked on the detail page, `null` for a
/// variant-less product — shared the same way [_selectedQuantityProvider]
/// is, between the swatch/chip picker, the price/stock display, and the
/// bottom action bar (which isn't a descendant of the widget that owns the
/// picker, hence needing Riverpod state rather than a local field).
/// `autoDispose` is safe here (unlike `buyNowItemProvider`): it's read and
/// written entirely while this screen stays mounted, the same
/// "write-then-read-from-a-still-watching-widget" shape
/// [_selectedQuantityProvider] already relies on — not the
/// "write-then-navigate-with-no-listener" shape that broke `buyNowItemProvider`.
final _selectedVariantIdProvider = StateProvider.autoDispose.family<String?, String>(
  (ref, productId) => null,
);

/// The client's specific pick for each characteristic where the selected
/// variant bundles more than one option together (e.g. "Taille" spanning
/// several sizes at one shared price/stock) — `ProductVariant.optionRefs`
/// alone can't say which exact size the client wants, only which ones the
/// supplier grouped together. Keyed by characteristic id; re-derived via
/// [_derivePicks] whenever the selected variant changes, same lifecycle as
/// [_selectedVariantIdProvider].
final _pickedOptionsProvider =
    StateProvider.autoDispose.family<Map<String, String>, String>(
      (ref, productId) => const {},
    );

/// [variant]'s own options, grouped by characteristic — a variant can list
/// *several* options for the same characteristic (e.g. one variant sold in
/// sizes S, M and L together), so each characteristic maps to a set, not a
/// single value.
Map<String, Set<String>> _optionsByCharacteristic(ProductVariant variant) {
  final result = <String, Set<String>>{};
  for (final r in variant.optionRefs) {
    (result[r.characteristicId] ??= {}).add(r.optionId);
  }
  return result;
}

/// The variant to land on when the client taps [optionId] for
/// [characteristicId], given what's already selected for every *other*
/// characteristic. Never a dead end: since one variant's options for a
/// characteristic aren't necessarily the same set as another's (e.g. a
/// "Noir" variant offering sizes 42/46/48 together vs. a "Rouge" one only
/// offering 46/48), requiring every other characteristic to still match
/// exactly — the old behaviour — could make a color that verifiably exists
/// unreachable purely because of which of *its own* variant's several sizes
/// happened to be showing. This instead prefers a variant that also matches
/// every other current selection where one exists, but falls back to any
/// variant offering [optionId] at all rather than resolving to nothing.
ProductVariant? _variantForOption(
  Product product,
  String characteristicId,
  String optionId,
  Map<String, Set<String>> currentSelection,
) {
  ProductVariant? fallback;
  for (final v in product.variants) {
    final byCharacteristic = _optionsByCharacteristic(v);
    if (!(byCharacteristic[characteristicId]?.contains(optionId) ?? false)) {
      continue;
    }
    fallback ??= v;
    final matchesOthers = currentSelection.entries
        .where((e) => e.key != characteristicId)
        .every(
          (e) => e.value.any((o) => byCharacteristic[e.key]?.contains(o) ?? false),
        );
    if (matchesOthers) return v;
  }
  return fallback;
}

/// For every characteristic [variant] carries: the single option to treat
/// as "picked" for it — the option itself when it's the only one,
/// [previous]'s pick carried over when it's still one of [variant]'s own
/// (e.g. switching color while keeping the same size), or left unset when
/// [variant] bundles several and neither of those applies — the client has
/// to tap one before checkout (see `_hasUnresolvedChoice`).
Map<String, String> _derivePicks(
  ProductVariant variant,
  Map<String, String> previous,
) {
  final byCharacteristic = _optionsByCharacteristic(variant);
  final result = <String, String>{};
  for (final entry in byCharacteristic.entries) {
    final own = entry.value;
    if (own.length == 1) {
      result[entry.key] = own.single;
    } else {
      final carriedOver = previous[entry.key];
      if (carriedOver != null && own.contains(carriedOver)) {
        result[entry.key] = carriedOver;
      }
    }
  }
  return result;
}

/// Whether [variant] bundles more than one option for some characteristic
/// (e.g. several sizes together) that [picks] hasn't resolved yet — blocks
/// "Acheter"/"Ajouter au panier" until it is, since the supplier otherwise
/// has no way to know which one to actually ship.
bool _hasUnresolvedChoice(ProductVariant variant, Map<String, String> picks) {
  final byCharacteristic = _optionsByCharacteristic(variant);
  return byCharacteristic.entries.any(
    (e) => e.value.length > 1 && !picks.containsKey(e.key),
  );
}

/// [variant] with its `name` narrowed to exactly what [picks] resolved
/// (e.g. "Noir 46" instead of the supplier's bundled "Noir 42 46 48") —
/// what actually gets snapshotted onto a cart/order item or a chat
/// attachment, so *which* size the client wants survives past this screen.
/// Falls back to [variant] unchanged if [picks] resolved nothing at all
/// (e.g. a plain single-option variant needs no narrowing to begin with).
ProductVariant _resolveVariantForPurchase(
  ProductVariant variant,
  Map<String, String> picks,
  List<ProductCharacteristic> characteristics,
) {
  final parts = [
    for (final c in characteristics.sortedBy((c) => c.displayOrder))
      if (picks[c.id] case final pickedId?)
        if (c.options.firstWhereOrNull((o) => o.id == pickedId) case final option?)
          option.value,
  ];
  return parts.isEmpty ? variant : variant.copyWith(name: parts.join(' '));
}

/// Starts (or resumes) the conversation with this product's supplier and
/// opens it with the product (and, if one is picked, [variant]) queued as a
/// pending attachment — see `ChatThreadScreen.initialAttachment` — so the
/// client's next message carries the exact name/price/photo automatically.
Future<void> _contactSupplierAboutProduct(
  BuildContext context,
  WidgetRef ref,
  Product product,
  ProductVariant? variant,
) async {
  final conversationId = await ref
      .read(chatControllerProvider.notifier)
      .startConversationWithSupplier(
        supplierId: product.supplierId,
        supplierName: product.supplierName,
      );
  if (!context.mounted || conversationId == null) return;
  unawaited(
    context.push(
      AppRoutes.chatThread(conversationId),
      extra: ChatProductAttachment(product: product, variant: variant),
    ),
  );
}

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  /// Flight target for [_flyCartonsToCart] — the AppBar's cart icon, so the
  /// "Ajouter au panier" animation has somewhere on screen to land on.
  final GlobalKey _cartIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Once per visit to this screen, not once per rebuild — `initState`
    // rather than `build`, and fired off `widget.productId` directly
    // rather than waiting on `productDetailProvider` to resolve, since the
    // count doesn't need the full product loaded first. Fire-and-forget:
    // a failed view-count bump shouldn't block or error the actual page.
    unawaited(
      ref.read(productRepositoryProvider).incrementViewCount(widget.productId),
    );
  }

  /// Sends [quantity] small cartons flying from [sourceCenter] (the "Ajouter
  /// au panier" button, at the moment it was tapped) to the AppBar's cart
  /// icon. Purely decorative — the real cart mutation already happened by
  /// the time this is called, so a missing target (e.g. mid hot-reload)
  /// just silently skips the animation instead of failing anything.
  void _flyCartonsToCart(Offset sourceCenter, int quantity) {
    final targetBox =
        _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached) return;
    final targetCenter = targetBox.localToGlobal(
      targetBox.size.center(Offset.zero),
    );

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingCartons(
        source: sourceCenter,
        target: targetCenter,
        // Capped so a bulk order doesn't throw a dozen icons across the
        // screen — the real count still lands correctly on the badge.
        count: quantity.clamp(1, 4),
        onCompleted: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final loadedProduct = productAsync.valueOrNull;
    final cartCount = ref.watch(cartItemCountProvider);
    final selectedVariantId = loadedProduct == null
        ? null
        : ref.watch(_selectedVariantIdProvider(loadedProduct.id));
    final picks = loadedProduct == null
        ? const <String, String>{}
        : ref.watch(_pickedOptionsProvider(loadedProduct.id));
    final selectedVariant = loadedProduct?.variants.firstWhereOrNull(
      (v) => v.id == selectedVariantId,
    );
    // Narrowed to the client's actual size/etc. pick where one was needed —
    // what the supplier should see, not the raw bundled variant.
    final resolvedVariant = selectedVariant == null || loadedProduct == null
        ? selectedVariant
        : _resolveVariantForPurchase(selectedVariant, picks, loadedProduct.characteristics);

    return Scaffold(
      appBar: AppBar(
        actions: loadedProduct == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  tooltip: 'Poser une question sur ce produit',
                  onPressed: () => _contactSupplierAboutProduct(
                    context,
                    ref,
                    loadedProduct,
                    resolvedVariant,
                  ),
                ),
                FavoriteToggleButton(productId: loadedProduct.id),
                IconButton(
                  key: _cartIconKey,
                  icon: AnimatedCountBadge(
                    count: cartCount,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  tooltip: 'Voir le panier',
                  // `go`, not `push` — clientCart is a StatefulShellRoute
                  // branch tab (see client_home_screen.dart's cart
                  // shortcut), and pushing it as a standalone route on top
                  // of the shell collides with the branch's own retained
                  // page instance.
                  onPressed: () => context.go(AppRoutes.clientCart),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
      ),
      body: AsyncValueWidget(
        value: productAsync,
        data: (product) => _ProductDetailContent(product: product),
      ),
      bottomNavigationBar:
          loadedProduct != null && loadedProduct.stockQuantity > 0
          ? _AddToCartBar(
              product: loadedProduct,
              selectedVariant: selectedVariant,
              picks: picks,
              onAddToCart: _flyCartonsToCart,
            )
          : null,
    );
  }
}

/// Owns the selected-photo state shared between the hero image and the
/// thumbnail strip beneath it, so tapping a thumbnail swipes the hero and
/// swiping the hero updates the selected thumbnail. Also drives an idle
/// auto-scroll (like [PromoHeroBanner]'s carousel) so a user who just
/// stares at the screen still sees every photo cycle through.
class _ProductDetailContent extends ConsumerStatefulWidget {
  const _ProductDetailContent({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductDetailContent> createState() =>
      _ProductDetailContentState();
}

class _ProductDetailContentState
    extends ConsumerState<_ProductDetailContent> {
  late final PageController _pageController;
  Timer? _idleAutoScrollTimer;
  int _selectedIndex = 0;

  /// Set right before an auto-scroll tick calls [PageController.animateToPage]
  /// and cleared once the resulting `onPageChanged` fires — lets
  /// [_onUserSelectedImage] tell that page change apart from one the client
  /// actually swiped, so a real swipe can stop the idle timer for good
  /// instead of just rescheduling it.
  bool _autoScrollInFlight = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (_images.length > 1) {
      _startIdleAutoScroll();
    }
    if (widget.product.hasVariants) {
      final defaultVariant =
          widget.product.variants.firstWhereOrNull((v) => v.isDefault) ??
          widget.product.variants.firstOrNull;
      if (defaultVariant != null) {
        // Riverpod forbids writing a provider synchronously from initState
        // (it runs during the widget tree's build phase) — defer to right
        // after this frame finishes building, same fix Riverpod's own error
        // message recommends.
        Future(() {
          if (!mounted) return;
          ref
              .read(_selectedVariantIdProvider(widget.product.id).notifier)
              .state = defaultVariant.id;
          ref
              .read(_pickedOptionsProvider(widget.product.id).notifier)
              .state = _derivePicks(defaultVariant, const {});
        });
      }
    }
  }

  @override
  void dispose() {
    _idleAutoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// The currently selected variant's own photos when it has any, else the
  /// base product's — read via `ref.read` since this is called from a
  /// timer/callback, not `build`.
  List<String> get _images {
    final variantId = ref.read(_selectedVariantIdProvider(widget.product.id));
    final variant = widget.product.variants.firstWhereOrNull(
      (v) => v.id == variantId,
    );
    if (variant != null && variant.imageUrls.isNotEmpty) return variant.imageUrls;
    return widget.product.imageUrls;
  }

  void _startIdleAutoScroll() {
    _idleAutoScrollTimer?.cancel();
    _idleAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final count = _images.length;
      final next = (_selectedIndex + 1) % count;
      _autoScrollInFlight = true;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  /// Fires for every page change, whichever caused it. An auto-scroll tick
  /// is tagged via [_autoScrollInFlight] right before it animates — anything
  /// else reaching here is the client's own swipe, which stops the idle
  /// timer for good instead of just rescheduling it, so the gallery never
  /// fights a photo the client is actively browsing.
  void _onUserSelectedImage(int index) {
    setState(() => _selectedIndex = index);
    if (_autoScrollInFlight) {
      _autoScrollInFlight = false;
    } else {
      _idleAutoScrollTimer?.cancel();
    }
  }

  void _openFullscreen() {
    final images = _images;
    if (images.isEmpty) return;
    _idleAutoScrollTimer?.cancel();
    showFullscreenImageViewer(
      context,
      images: images,
      initialIndex: _selectedIndex,
    );
  }

  /// Fired when the picker resolves a different variant — switches the
  /// gallery to that variant's own photos (falling back to the product's)
  /// and restarts browsing from its first photo, same as opening a
  /// different product would.
  void _onVariantChanged() {
    if (!_pageController.hasClients) return;
    setState(() => _selectedIndex = 0);
    _pageController.jumpToPage(0);
    if (_images.length > 1) {
      _startIdleAutoScroll();
    } else {
      _idleAutoScrollTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    ref.listen(_selectedVariantIdProvider(product.id), (previous, next) {
      if (previous == next) return;
      _onVariantChanged();
      // A quantity picked against the previous variant's stock could
      // exceed the new one's — reset rather than silently clamp, so the
      // stepper never shows a number the client didn't actually choose.
      ref.read(_selectedQuantityProvider(product.id).notifier).state = 1;
      final variant = product.variants.firstWhereOrNull((v) => v.id == next);
      if (variant != null) {
        final previousPicks = ref.read(_pickedOptionsProvider(product.id));
        ref.read(_pickedOptionsProvider(product.id).notifier).state = _derivePicks(
          variant,
          previousPicks,
        );
      }
    });

    final selectedVariantId = ref.watch(_selectedVariantIdProvider(product.id));
    final picks = ref.watch(_pickedOptionsProvider(product.id));
    final selectedVariant = product.variants.firstWhereOrNull(
      (v) => v.id == selectedVariantId,
    );
    final images = _images;
    final resolvedStock = selectedVariant?.stockQuantity ?? product.stockQuantity;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GestureDetector(
          onTap: images.isEmpty ? null : _openFullscreen,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                images.length <= 1
                    ? ProductImage(
                        imageUrl: images.isEmpty ? null : images.first,
                        icon: product.category.icon,
                      )
                    : PageView.builder(
                        key: ValueKey(selectedVariantId),
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: _onUserSelectedImage,
                        itemBuilder: (context, index) => ProductImage(
                          imageUrl: images[index],
                          icon: product.category.icon,
                        ),
                      ),
                // La vidéo de la variante sélectionnée, en pastille sur la
                // galerie plutôt qu'en page supplémentaire du carrousel :
                // elle reste là où l'acheteur regarde les photos, sans que
                // la pagination (index courant, plein écran) ait à composer
                // avec une page qui n'est pas une image.
                if (selectedVariant?.videoPath != null)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _VideoBadge(videoPath: selectedVariant!.videoPath!),
                  ),
                if (images.isNotEmpty)
                  Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _PromotionalPrice(
                      product: product,
                      basePriceFcfa:
                          selectedVariant?.priceFcfa ?? product.priceFcfa,
                    ),
                  ),
                  if (resolvedStock > 0)
                    _InlineQuantityStepper(
                      product: product,
                      stockQuantity: resolvedStock,
                    ),
                ],
              ),
              _NextQuantityStepHint(
                product: product,
                basePriceFcfa: selectedVariant?.priceFcfa ?? product.priceFcfa,
              ),
              if (product.hasVariants) ...[
                const SizedBox(height: AppSpacing.md),
                _VariantPicker(
                  product: product,
                  selectedVariantId: selectedVariantId,
                  picks: picks,
                  onSelected: (id) => ref
                      .read(_selectedVariantIdProvider(product.id).notifier)
                      .state = id,
                  onPick: (characteristicId, optionId) {
                    final current = ref.read(_pickedOptionsProvider(product.id));
                    ref.read(_pickedOptionsProvider(product.id).notifier).state = {
                      ...current,
                      characteristicId: optionId,
                    };
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _SupplierTile(product: product),
              const Divider(height: AppSpacing.xl),
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                product.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _StockAndDelivery(
                product: product,
                resolvedStockQuantity: resolvedStock,
              ),
              const Divider(height: AppSpacing.xl),
              _CommentsEntryRow(productId: product.id),
              const Divider(height: AppSpacing.xl),
              // Les avis sont dans la page, les commentaires derrière une
              // ligne : un avis se lit avant d'acheter, une question se
              // consulte quand on en a une.
              ProductReviewsSection(productId: product.id),
            ],
          ),
        ),
        _SimilarProducts(product: product),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Tappable summary row that opens [ProductCommentsModal] — shows the live
/// comment count so there's a reason to tap even before any reply is
/// visible on the page itself.
class _CommentsEntryRow extends ConsumerWidget {
  const _CommentsEntryRow({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final commentsAsync = ref.watch(productCommentsProvider(productId));
    final count = commentsAsync.valueOrNull?.length ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => showProductCommentsModal(context, productId: productId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.mode_comment_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                count > 0 ? 'Commentaires ($count)' : 'Commentaires',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Compact +/- stepper sat next to the price, sharing
/// [_selectedQuantityProvider] with the bottom action bar.
class _InlineQuantityStepper extends ConsumerWidget {
  const _InlineQuantityStepper({
    required this.product,
    required this.stockQuantity,
  });

  final Product product;

  /// The currently *selected variant's* stock when the product has
  /// variants, else the product's own — the cap this stepper enforces.
  final int stockQuantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(_selectedQuantityProvider(product.id));
    final scheme = Theme.of(context).colorScheme;

    const buttonConstraints = BoxConstraints.tightFor(width: 30, height: 30);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 16),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: buttonConstraints,
            onPressed: quantity > 1
                ? () => ref
                      .read(_selectedQuantityProvider(product.id).notifier)
                      .state--
                : null,
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 16),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: buttonConstraints,
            onPressed: quantity < stockQuantity
                ? () => ref
                      .read(_selectedQuantityProvider(product.id).notifier)
                      .state++
                : null,
          ),
        ],
      ),
    );
  }
}

/// Renders one row per characteristic — a swatch row (photo thumbnails) for
/// `couleur`, a chip row for everything else — driven entirely by
/// [product]'s already-saved variants. An option stays tappable only when
/// some variant carries it *together with* whatever's already picked for
/// every other characteristic (see `reachable` below) — so picking "Rouge"
/// narrows the "Taille" row down to only the sizes Rouge actually comes in,
/// instead of showing every size that exists for any color. Before anything
/// is picked that check is vacuously true, so every option attached to at
/// least one variant starts out tappable; only options nobody ever built a
/// variant for at all stay grayed out.
class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.product,
    required this.selectedVariantId,
    required this.picks,
    required this.onSelected,
    required this.onPick,
  });

  final Product product;
  final String? selectedVariantId;

  /// The client's specific pick per characteristic where the selected
  /// variant bundles more than one option — see `_derivePicks`.
  final Map<String, String> picks;
  final ValueChanged<String> onSelected;
  final void Function(String characteristicId, String optionId) onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedVariant = product.variants.firstWhereOrNull(
      (v) => v.id == selectedVariantId,
    );
    final selection = selectedVariant == null
        ? const <String, Set<String>>{}
        : _optionsByCharacteristic(selectedVariant);

    final characteristics = product.characteristics.sortedBy(
      (c) => c.displayOrder,
    );

    void selectOption(String characteristicId, String optionId) {
      final variant = _variantForOption(product, characteristicId, optionId, selection);
      if (variant == null) return;
      // Record the tap itself *before* switching variants, not after: the
      // switch below re-derives `picks` from scratch for the destination
      // variant (see the `ref.listen` on `_selectedVariantIdProvider`
      // above), and when that variant is itself bundled on this same
      // characteristic (e.g. "Rouge" sold in S/M/L together), pure
      // carry-over logic (`_derivePicks`) has no way to know which of those
      // several options the client actually meant — only that whichever
      // one was already picked (if any) still applies. Pre-seeding it here
      // means it's already the "previous" pick `_derivePicks` carries
      // over, since `variant` is guaranteed (by `_variantForOption`) to
      // list [optionId] among its own options for [characteristicId].
      // Without this, the first tap on such a value looked like it did
      // nothing — "Choisissez une valeur." stayed up, the buy button
      // stayed disabled — until a second, identical tap resolved it.
      onPick(characteristicId, optionId);
      onSelected(variant.id);
    }

    // True when some variant carries [optionId] for [characteristicId] *and*
    // also matches every other characteristic already selected (e.g. also
    // carries the currently picked color) — not just when the option exists
    // on any variant of the product at all. With nothing selected yet,
    // `selection` is empty and the `.every` below is vacuously true, so this
    // falls back to "exists anywhere" exactly like before a selection is made.
    bool reachable(String characteristicId, String optionId) {
      return product.variants.any((v) {
        final byCharacteristic = _optionsByCharacteristic(v);
        if (!(byCharacteristic[characteristicId]?.contains(optionId) ?? false)) {
          return false;
        }
        return selection.entries
            .where((e) => e.key != characteristicId)
            .every(
              (e) => e.value.any((o) => byCharacteristic[e.key]?.contains(o) ?? false),
            );
      });
    }

    final rows = <Widget>[];
    for (final characteristic in characteristics) {
      final variantOptions = selection[characteristic.id] ?? const <String>{};
      // The selected variant itself listing more than one option for this
      // characteristic (e.g. sizes 42/46/48 sold together) can't be
      // resolved to a *different* variant by tapping among them — they all
      // point at this same one — so that just records which one the client
      // actually wants instead of searching for a variant switch that could
      // never find anything new.
      final isBundled = variantOptions.length > 1;
      final pickedId = picks[characteristic.id];
      final highlighted = isBundled
          ? (pickedId != null ? {pickedId} : const <String>{})
          : variantOptions;

      void onTap(String optionId) {
        if (variantOptions.contains(optionId)) {
          onPick(characteristic.id, optionId);
        } else {
          selectOption(characteristic.id, optionId);
        }
      }

      rows.add(
        characteristic.type.id == 'couleur'
            ? _VariantSwatchRow(
                product: product,
                characteristic: characteristic,
                selectedOptionIds: highlighted,
                isReachable: (optionId) => reachable(characteristic.id, optionId),
                onSelected: onTap,
              )
            : _VariantChipRow(
                characteristic: characteristic,
                selectedOptionIds: highlighted,
                isReachable: (optionId) => reachable(characteristic.id, optionId),
                onSelected: onTap,
              ),
      );
      if (isBundled && pickedId == null) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Choisissez une valeur.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        );
      }
      rows.add(const SizedBox(height: AppSpacing.md));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// Pastille « Vidéo » posée sur la galerie quand la variante sélectionnée en
/// a une, ouvrant le lecteur plein écran.
class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.videoPath});

  final String videoPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: () => showVariantVideo(context, videoPath),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text(
                'Vidéo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small square photo thumbnails for the `couleur` characteristic — the
/// swatch/label pairing from the Wildberries-style reference: each option's
/// thumbnail is the first photo of any variant carrying that color, falling
/// back to the base product's photos when none has its own.
class _VariantSwatchRow extends StatelessWidget {
  const _VariantSwatchRow({
    required this.product,
    required this.characteristic,
    required this.selectedOptionIds,
    required this.isReachable,
    required this.onSelected,
  });

  final Product product;
  final ProductCharacteristic characteristic;

  /// Every one of the currently selected variant's own options for this
  /// characteristic — plural because one variant can list several (e.g.
  /// sizes 42/46/48 sold together), so more than one chip highlights at once.
  final Set<String> selectedOptionIds;
  final bool Function(String optionId) isReachable;
  final ValueChanged<String> onSelected;

  String? _thumbnailFor(String optionId) {
    final variant = product.variants.firstWhereOrNull(
      (v) => v.optionRefs.any(
        (r) => r.characteristicId == characteristic.id && r.optionId == optionId,
      ),
    );
    final photo = variant?.imageUrls.firstOrNull;
    return photo ?? product.imageUrls.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = characteristic.options.sortedBy((o) => o.displayOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(characteristic.type.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          // 64 for the photo + spacing + a line of label underneath it —
          // every option gets its own name, not just whichever one happens
          // to be selected right now.
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final option = options[index];
              final selected = selectedOptionIds.contains(option.id);
              final reachable = isReachable(option.id);
              return Opacity(
                opacity: reachable ? 1 : 0.35,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  onTap: reachable ? () => onSelected(option.id) : null,
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          padding: EdgeInsets.all(selected ? 3 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: selected ? scheme.primary : scheme.outlineVariant,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm - (selected ? 2 : 1),
                            ),
                            child: ProductImage(
                              imageUrl: _thumbnailFor(option.id),
                              icon: product.category.icon,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          option.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: selected ? scheme.primary : null,
                            fontWeight: selected ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Chip row for every non-`couleur` characteristic (stockage/taille/poids/
/// approved custom types) — visually identical to the old dead
/// `_VariantSelector`, just wired into real price/stock now.
class _VariantChipRow extends StatelessWidget {
  const _VariantChipRow({
    required this.characteristic,
    required this.selectedOptionIds,
    required this.isReachable,
    required this.onSelected,
  });

  final ProductCharacteristic characteristic;

  /// Every one of the currently selected variant's own options for this
  /// characteristic — plural because one variant can list several (e.g.
  /// sizes 42/46/48 sold together), so more than one chip highlights at once.
  final Set<String> selectedOptionIds;
  final bool Function(String optionId) isReachable;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = characteristic.options.sortedBy((o) => o.displayOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(characteristic.type.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              Opacity(
                opacity: isReachable(option.id) ? 1 : 0.35,
                child: ChoiceChip(
                  label: Text(option.value),
                  selected: selectedOptionIds.contains(option.id),
                  selectedColor: scheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: selectedOptionIds.contains(option.id) ? 14 : 10,
                    vertical: selectedOptionIds.contains(option.id) ? 10 : 6,
                  ),
                  side: BorderSide(
                    color: selectedOptionIds.contains(option.id)
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: selectedOptionIds.contains(option.id) ? 2.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: selectedOptionIds.contains(option.id)
                        ? scheme.onPrimary
                        : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: isReachable(option.id)
                      ? (_) => onSelected(option.id)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Voir aussi" — other products in the same category from the same side of
/// the catalog (tiers/principal), so browsing a product naturally surfaces
/// alternatives without a full search round-trip.
class _SimilarProducts extends ConsumerWidget {
  const _SimilarProducts({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(similarProductsProvider(product));

    return similarAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Voir aussi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 270,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => SizedBox(
                  width: 150,
                  child: ProductCard(product: products[index]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dual-action bottom bar — a quick "Acheter" that jumps straight to
/// checkout for just the selected quantity of this one product (via
/// `buyNowItemProvider`, bypassing the shared cart entirely), and the
/// regular "Ajouter au panier" that adds it to the cart instead. Both read
/// the same [_selectedQuantityProvider] the inline stepper next to the
/// price writes to, so there's a single source of truth for "how many".
class _AddToCartBar extends ConsumerStatefulWidget {
  const _AddToCartBar({
    required this.product,
    required this.selectedVariant,
    required this.picks,
    required this.onAddToCart,
  });

  final Product product;

  /// The variant currently picked above, if [product] has any — resolves
  /// which price/stock/id "Acheter"/"Ajouter au panier" actually act on.
  final ProductVariant? selectedVariant;

  /// The client's specific pick per characteristic where [selectedVariant]
  /// bundles more than one option — see `_derivePicks`.
  final Map<String, String> picks;

  /// Called with the "Ajouter au panier" button's on-screen center and the
  /// quantity just added, so the parent screen can fly cartons from here to
  /// its cart icon.
  final void Function(Offset sourceCenter, int quantity) onAddToCart;

  @override
  ConsumerState<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends ConsumerState<_AddToCartBar> {
  final GlobalKey _addToCartButtonKey = GlobalKey();

  void _launchCartonFlight(int quantity) {
    final box =
        _addToCartButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    widget.onAddToCart(box.localToGlobal(box.size.center(Offset.zero)), quantity);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final variant = widget.selectedVariant;
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final quantity = ref.watch(_selectedQuantityProvider(product.id));
    // The product overall is purchasable (the outer bottom-bar visibility
    // guard already checked the aggregate stock), but the *specific*
    // variant currently picked might itself be out — disable just the
    // buttons then, so the price row stays visible and the client can see
    // it's this particular variant that's unavailable, not the product.
    final variantOutOfStock = product.hasVariants && (variant?.stockQuantity ?? 0) <= 0;
    // The selected variant bundles several options for some characteristic
    // (e.g. sizes 42/46/48 together) and the client hasn't tapped one yet —
    // there'd be no way to tell the supplier which one to ship.
    final needsChoice = variant != null && _hasUnresolvedChoice(variant, widget.picks);
    final disabled = variantOutOfStock || needsChoice;
    // Narrowed to exactly what the client picked (e.g. "Noir 46") — this,
    // not the supplier's raw bundled variant, is what gets snapshotted onto
    // the cart/order item.
    final resolvedVariant = variant == null
        ? null
        : _resolveVariantForPurchase(variant, widget.picks, product.characteristics);
    final buttonLabel = variantOutOfStock
        ? 'Variante en rupture'
        : needsChoice
        ? 'Choisissez une taille'
        : 'Ajouter au panier';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: AppShadows.bar(brightness),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: disabled
                    ? null
                    : () {
                        final user = ref.read(currentUserProvider).valueOrNull;
                        if (user == null) return;
                        // Stages a buy-now override instead of adding to the
                        // shared cart — checkout then builds its single group
                        // from just this product, so anything else already
                        // sitting in the client's cart is left untouched and
                        // isn't purchased alongside it.
                        ref.read(buyNowItemProvider.notifier).state = CartItem(
                          id: 'buy-now-${product.id}',
                          userId: user.id,
                          productId: product.id,
                          supplierId: product.supplierId,
                          productNameSnapshot: product.name,
                          unitPriceFcfaSnapshot:
                              resolvedVariant?.priceFcfa ?? product.priceFcfa,
                          quantity: quantity,
                          addedAt: DateTime.now(),
                          variantId: resolvedVariant?.id,
                          variantNameSnapshot: resolvedVariant?.name,
                        );
                        unawaited(context.push(AppRoutes.clientCheckout));
                      },
                child: const Text('Acheter'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: MtcPrimaryButton(
                key: _addToCartButtonKey,
                label: buttonLabel,
                icon: Icons.add_shopping_cart_rounded,
                onPressed: disabled
                    ? null
                    : () {
                        // Fired alongside the real mutation (not awaited after
                        // it) so the flight animation and the cart badge update
                        // together instead of the button feeling like it's
                        // waiting on the animation to finish. The flight itself
                        // is the "added to cart" feedback now, so no snackbar.
                        _launchCartonFlight(quantity);
                        unawaited(
                          ref
                              .read(cartControllerProvider.notifier)
                              .addProduct(
                                product,
                                quantity: quantity,
                                variant: resolvedVariant,
                              ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small cartons that toss themselves from [source] (the "Ajouter au
/// panier" button) to [target] (the AppBar's cart icon) along an arced
/// path, shrinking and fading as they arrive — a lightweight, purely
/// visual echo of [LoadingScreen]'s falling crates, confirming "this went
/// into the cart" without waiting on the real cart state to catch up.
class _FlyingCartons extends StatefulWidget {
  const _FlyingCartons({
    required this.source,
    required this.target,
    required this.count,
    required this.onCompleted,
  });

  final Offset source;
  final Offset target;
  final int count;
  final VoidCallback onCompleted;

  @override
  State<_FlyingCartons> createState() => _FlyingCartonsState();
}

class _FlyingCartonsState extends State<_FlyingCartons>
    with SingleTickerProviderStateMixin {
  static const _cartonSize = 32.0;
  static const _stagger = 0.1;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onCompleted();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _cartonProgress(int index, double t) {
    final start = index * _stagger;
    const span = 1 - _stagger * 3; // leaves room for up to 4 cartons
    return ((t - start) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              for (var i = 0; i < widget.count; i++)
                _carton(index: i, t: _controller.value),
            ],
          );
        },
      ),
    );
  }

  Widget _carton({required int index, required double t}) {
    final progress = Curves.easeIn.transform(_cartonProgress(index, t));
    final linear = Offset.lerp(widget.source, widget.target, progress)!;
    // Arcs upward at the midpoint instead of cutting straight across.
    final arc = -70.0 * math.sin(math.pi * progress);
    final position = linear + Offset(0, arc);
    final scale = 1 - progress * 0.6;
    final opacity = progress < 0.85 ? 1.0 : (1 - progress) / 0.15;

    return Positioned(
      left: position.dx - _cartonSize / 2,
      top: position.dy - _cartonSize / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: progress * (index.isEven ? -1.4 : 1.4),
            child: Icon(
              Icons.inventory_2_rounded,
              size: _cartonSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => context.push(AppRoutes.supplierProfile(product.supplierId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.storefront_rounded,
                color: scheme.onPrimaryContainer,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.supplierName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    product.city,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            MtcRatingStars(
              rating: product.ratingAverage,
              ratingCount: product.ratingCount,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _StockAndDelivery extends StatelessWidget {
  const _StockAndDelivery({
    required this.product,
    required this.resolvedStockQuantity,
  });

  final Product product;

  /// The currently *selected variant's* stock when the product has
  /// variants, else the product's own.
  final int resolvedStockQuantity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final inStock = resolvedStockQuantity > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.soft(brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                inStock
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                size: 18,
                color: inStock ? scheme.primary : scheme.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                inStock
                    ? '$resolvedStockQuantity en stock'
                    : 'Rupture de stock',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (product.allowsSelfDelivery)
            const _DeliveryRow(
              icon: Icons.storefront_outlined,
              label: 'Livraison par le fournisseur',
            ),
          if (product.allowsMtcDelivery)
            const _DeliveryRow(
              icon: Icons.local_shipping_outlined,
              // Exact fee depends on the delivery address (distance/poids/
              // catégorie) — computed at checkout, see delivery_pricing.dart.
              label: 'Livraison MTC (1000 - 4000 FCFA selon la distance)',
            ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Le prix de la fiche, remise appliquée pour la quantité choisie.
///
/// La quantité compte : une remise « dès 10 pièces » ne doit pas s'afficher
/// à 1, sinon la fiche annonce un prix que le panier démentira. Le prix
/// barré est alors le prix plein, et non `compare_at_price_fcfa` — ce
/// dernier est un prix barré décoratif, antérieur aux promotions.
class _PromotionalPrice extends ConsumerWidget {
  const _PromotionalPrice({
    required this.product,
    required this.basePriceFcfa,
  });

  final Product product;
  final int basePriceFcfa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final quantity = ref.watch(_selectedQuantityProvider(product.id));
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.bold,
    );

    final promotion = bestPromotionFor(
      promotions: product.promotions,
      basePriceFcfa: basePriceFcfa,
      quantity: quantity,
    );
    if (promotion == null) {
      return CurrencyText(
        basePriceFcfa,
        compareAtAmountFcfa: product.compareAtPriceFcfa,
        style: style,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: CurrencyText(
            priceUnderPromotion(
              basePriceFcfa: basePriceFcfa,
              promotion: promotion,
            ),
            compareAtAmountFcfa: basePriceFcfa,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PromotionBadge(promotion: promotion),
      ],
    );
  }
}

/// « Encore 3 pour -20% » : une remise sur quantité que personne ne voit ne
/// fait pas vendre une unité de plus.
class _NextQuantityStepHint extends ConsumerWidget {
  const _NextQuantityStepHint({
    required this.product,
    required this.basePriceFcfa,
  });

  final Product product;
  final int basePriceFcfa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(_selectedQuantityProvider(product.id));
    final step = nextQuantityStep(
      promotions: product.promotions,
      basePriceFcfa: basePriceFcfa,
      quantity: quantity,
    );
    if (step == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final price = priceUnderPromotion(
      basePriceFcfa: basePriceFcfa,
      promotion: step.promotion,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.trending_down_rounded, size: 16, color: scheme.tertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Encore ${step.unitsMissing} '
              '${step.unitsMissing > 1 ? 'unités' : 'unité'} pour '
              '${CurrencyFormatter.formatFcfa(price)} l\'unité',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
