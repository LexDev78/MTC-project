import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/comments/presentation/widgets/product_comments_modal.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../../domain/entities/product.dart';
import '../providers/catalog_providers.dart';
import '../widgets/fullscreen_image_viewer.dart';
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

/// Starts (or resumes) the conversation with this product's supplier and
/// opens it with the product queued as a pending attachment — see
/// [ChatThreadScreen.initialProduct] — so the client's next message carries
/// the product's name/price/photo automatically.
Future<void> _contactSupplierAboutProduct(
  BuildContext context,
  WidgetRef ref,
  Product product,
) async {
  final conversationId = await ref
      .read(chatControllerProvider.notifier)
      .startConversationWithSupplier(
        supplierId: product.supplierId,
        supplierName: product.supplierName,
      );
  if (!context.mounted || conversationId == null) return;
  unawaited(
    context.push(AppRoutes.chatThread(conversationId), extra: product),
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
          ? _AddToCartBar(product: loadedProduct, onAddToCart: _flyCartonsToCart)
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
  late String? _selectedSize = widget.product.sizes.isEmpty
      ? null
      : widget.product.sizes.first;
  late String? _selectedColor = widget.product.colors.isEmpty
      ? null
      : widget.product.colors.first;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.product.imageUrls.length > 1) {
      _startIdleAutoScroll();
    }
  }

  @override
  void dispose() {
    _idleAutoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startIdleAutoScroll() {
    _idleAutoScrollTimer?.cancel();
    _idleAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final count = widget.product.imageUrls.length;
      final next = (_selectedIndex + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  /// Any user-driven photo change (swipe or thumbnail tap) resets the idle
  /// clock, so auto-scroll only kicks in after real inactivity rather than
  /// fighting a page the user is actively browsing.
  void _onUserSelectedImage(int index) {
    setState(() => _selectedIndex = index);
    if (widget.product.imageUrls.length > 1) _startIdleAutoScroll();
  }

  void _selectImage(int index) {
    _onUserSelectedImage(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _openFullscreen() {
    final images = widget.product.imageUrls;
    if (images.isEmpty) return;
    _idleAutoScrollTimer?.cancel();
    showFullscreenImageViewer(
      context,
      images: images,
      initialIndex: _selectedIndex,
    ).whenComplete(() {
      if (mounted && widget.product.imageUrls.length > 1) {
        _startIdleAutoScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final images = product.imageUrls;

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
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: _onUserSelectedImage,
                        itemBuilder: (context, index) => ProductImage(
                          imageUrl: images[index],
                          icon: product.category.icon,
                        ),
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
              if (images.length > 1) ...[
                _ThumbnailStrip(
                  images: images,
                  selectedIndex: _selectedIndex,
                  onSelected: _selectImage,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: CurrencyText(
                      product.priceFcfa,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (product.stockQuantity > 0)
                    _InlineQuantityStepper(product: product),
                ],
              ),
              if (product.colors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _VariantSelector(
                  label: 'Couleur',
                  options: product.colors,
                  selected: _selectedColor,
                  onSelected: (value) =>
                      setState(() => _selectedColor = value),
                ),
              ],
              if (product.sizes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _VariantSelector(
                  label: 'Taille',
                  options: product.sizes,
                  selected: _selectedSize,
                  onSelected: (value) => setState(() => _selectedSize = value),
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
              _StockAndDelivery(product: product),
              const Divider(height: AppSpacing.xl),
              _CommentsEntryRow(productId: product.id),
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
  const _InlineQuantityStepper({required this.product});

  final Product product;

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
            onPressed: quantity < product.stockQuantity
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

/// A row of selectable chips for one variant axis (color or size) — purely
/// a browsing/comparison aid for now; the cart doesn't track per-variant
/// selection yet, so this doesn't change price or stock.
class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final void Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: option == selected,
                selectedColor: scheme.primary,
                labelStyle: TextStyle(
                  color: option == selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onSelected(option),
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

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.images,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> images;
  final int selectedIndex;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            onTap: () => onSelected(index),
            child: Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Image.asset(images[index], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

/// Dual-action bottom bar — a quick "Acheter" that adds the selected
/// quantity straight to the cart and jumps to checkout, and the regular
/// "Ajouter au panier" that just adds it. Both read the same
/// [_selectedQuantityProvider] the inline stepper next to the price writes
/// to, so there's a single source of truth for "how many".
class _AddToCartBar extends ConsumerStatefulWidget {
  const _AddToCartBar({required this.product, required this.onAddToCart});

  final Product product;

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
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final quantity = ref.watch(_selectedQuantityProvider(product.id));

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
                onPressed: () async {
                  await ref
                      .read(cartControllerProvider.notifier)
                      .addProduct(product, quantity: quantity);
                  if (context.mounted) {
                    unawaited(context.push(AppRoutes.clientCheckout));
                  }
                },
                child: const Text('Acheter'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: MtcPrimaryButton(
                key: _addToCartButtonKey,
                label: 'Ajouter au panier',
                icon: Icons.add_shopping_cart_rounded,
                onPressed: () {
                  // Fired alongside the real mutation (not awaited after
                  // it) so the flight animation and the cart badge update
                  // together instead of the button feeling like it's
                  // waiting on the animation to finish. The flight itself
                  // is the "added to cart" feedback now, so no snackbar.
                  _launchCartonFlight(quantity);
                  unawaited(
                    ref
                        .read(cartControllerProvider.notifier)
                        .addProduct(product, quantity: quantity),
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
  const _StockAndDelivery({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final inStock = product.stockQuantity > 0;

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
                    ? '${product.stockQuantity} en stock'
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
