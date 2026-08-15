-- Adds a nullable `reference_id` to `notifications` so tapping one in
-- `NotificationCenterScreen` can navigate straight to what it's about —
-- the conversation for a `new_message`, the order for a `new_order`. Other
-- types (`low_stock`, `kyc_decision`, `payout_decision`, `new_review`) have
-- no ready-made detail route to land on yet, so they keep leaving this
-- null (tap still just marks read, same as before).
alter table public.notifications add column reference_id text;
