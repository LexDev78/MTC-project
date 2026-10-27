-- A variant can now carry more than one option for the same characteristic
-- — e.g. one "Rouge" variant sold in sizes S, M and L together (one shared
-- price/stock), rather than needing three separate variants exploded per
-- exact size. The old primary key (variant_id, characteristic_id) allowed
-- exactly one option per characteristic per variant; widen it to also
-- include option_id so several rows for the same (variant, characteristic)
-- pair are legal.
alter table public.product_variant_options drop constraint product_variant_options_pkey;
alter table public.product_variant_options
  add primary key (variant_id, characteristic_id, option_id);
