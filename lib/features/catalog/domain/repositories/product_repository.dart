import '../entities/product.dart';
import '../entities/product_category.dart';
import '../entities/product_characteristic.dart';
import '../entities/product_status.dart';
import '../entities/product_variant.dart';
import '../entities/stock_movement.dart';

/// A product's favorite ("j'aime") and order counts, aggregated
/// server-side — see [ProductRepository.fetchProductStats]. Neither figure
/// lives on [Product] itself (unlike [Product.viewCount]): both come from
/// separate tables (`favorites`, `order_items`), so a plain value bag
/// keyed by product id is enough — no need for a full domain entity.
typedef ProductStats = ({int favoriteCount, int orderCount});

abstract interface class ProductRepository {
  Stream<List<Product>> watchProducts({
    SupplierType? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  });

  Future<Product> getById(String id);

  /// Propagates a supplier's newly recomputed rating to every one of their
  /// products — `Product.ratingAverage/ratingCount` is a denormalized copy
  /// (so catalog sorting/filtering never needs a supplier join), and a
  /// review only updates the supplier record directly.
  Future<void> updateSupplierRating({
    required String supplierId,
    required double ratingAverage,
    required int ratingCount,
  });

  /// Every product belonging to [supplierId], regardless of verification or
  /// `ProductStatus` — the supplier's own management view. Unlike
  /// [watchProducts], which only ever shows what a client is allowed to
  /// see, this never filters anything out.
  Stream<List<Product>> watchMyProducts(String supplierId);

  /// Creates a new listing, starting as `ProductStatus.draft` — the
  /// supplier explicitly activates it via [setStatus] once it's ready,
  /// rather than a half-filled listing going live by accident.
  Future<Product> createProduct({
    required String supplierId,
    required String supplierName,
    required SupplierType supplierType,
    required bool isSupplierVerified,
    required String name,
    required String description,
    required ProductCategory category,
    required int priceFcfa,
    required int stockQuantity,
    required double weightKg,
    required String city,
    required List<String> imageUrls,
    required bool allowsSelfDelivery,
    required bool allowsMtcDelivery,
    required List<String> sizes,
    required List<String> colors,
    required ProductRegion region,
    int? lowStockThreshold,
    int? compareAtPriceFcfa,
  });

  /// Replaces the stored record for `product.id` with [product] — the
  /// caller (the product form) loads the existing product, applies edits
  /// via `copyWith`, and passes the full result back rather than a partial
  /// patch, so there's no ambiguity between "field left unchanged" and
  /// "field cleared".
  Future<void> updateProduct(Product product);

  Future<void> setStatus({required String id, required ProductStatus status});

  /// The single write path for every stock change, manual or automatic
  /// (`place_order` decrements on its own atomically — see
  /// `0019_place_order_variants.sql` — this is the manual-correction path:
  /// the supplier form, `SupplierStockAdjustSheet`) — so
  /// [watchStockMovements] always reflects the complete history. Throws
  /// `InsufficientStockException` if [quantityDelta] would take stock below
  /// zero. [variantId] targets that variant's own stock instead of the
  /// product's — required once the product `hasVariants`.
  Future<void> adjustStock({
    required String id,
    required int quantityDelta,
    required StockMovementReason reason,
    String? variantId,
    String? note,
  });

  /// Full replace of [productId]'s characteristics/options/variants — see
  /// `SupabaseProductDatasource.replaceCharacteristicsAndVariants` for the
  /// exact semantics (not a diff/patch).
  Future<void> replaceCharacteristicsAndVariants({
    required String productId,
    required List<ProductCharacteristic> characteristics,
    required List<ProductVariant> variants,
  });

  Stream<List<StockMovement>> watchStockMovements(String productId);

  /// Propagates a staff KYC decision to every one of a supplier's products
  /// — `Product.isSupplierVerified` is a denormalized copy of the account's
  /// verification state (same reasoning as [updateSupplierRating]). Called
  /// by `KycReviewController` alongside `AuthRepository`/`SupplierRepository`
  /// — never invoked from within another repository.
  Future<void> updateSupplierVerification({
    required String supplierId,
    required bool isVerified,
  });

  /// Bumps [Product.viewCount] by one — called once per client visit to
  /// `ProductDetailScreen`. No RLS write path exists for an arbitrary
  /// client to touch another supplier's product row directly, so this
  /// goes through a `security definer` RPC (`0014_product_stats.sql`).
  Future<void> incrementViewCount(String productId);

  /// Favorite/order counts for every one of [supplierId]'s products, keyed
  /// by product id — powers the supplier dashboard's product cards. One
  /// aggregate RPC call rather than N queries/subscriptions.
  Future<Map<String, ProductStats>> fetchProductStats(String supplierId);
}
