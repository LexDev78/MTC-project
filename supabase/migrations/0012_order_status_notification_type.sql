-- New `notification_type` value for order status changes pushed to the
-- CLIENT (accepted/preparing/shipped/delivered/cancelled by the supplier) —
-- distinct from `new_order`, which goes the other way (to the supplier when
-- a client places an order). `alter type ... add value` cannot run inside
-- the same transaction as a later statement that uses the new value, but
-- this migration only adds the value — nothing else needs it yet.
alter type public.notification_type add value 'order_status_update';
