-- Removes schema that turned out to have zero real usage anywhere — confirmed
-- by an exhaustive grep across `lib/` (Dart reads outside generated
-- `.freezed.dart`/`.g.dart` files), every `data/datasources/*.dart` query
-- string, and every SQL trigger/RPC body:
--
-- - `suppliers.avatar_url`: never read (no supplier avatar display exists
--   anywhere) and never written (no signup/profile-edit flow sets it) —
--   present on the `SupplierProfile` entity but nothing ever touches the
--   field.
-- - `product_variants.created_at`: not even on the `ProductVariant` entity
--   (silently dropped by `fromJson`); never selected/ordered-by, never
--   referenced by `recompute_product_variant_aggregates` (0018).
-- - `public.pickup_points` (whole table): the checkout pickup-point picker
--   (`checkout_providers.dart`'s `pickupPointsProvider`) reads a hardcoded
--   `mockPickupPoints` list (`lib/features/orders/data/mock_pickup_points.dart`)
--   instead — no datasource anywhere calls `.from('pickup_points')`. The
--   `PickupPoint` Dart entity and the mock data stay; only this orphaned,
--   always-empty table goes.
alter table public.suppliers drop column avatar_url;
alter table public.product_variants drop column created_at;
drop table public.pickup_points;
