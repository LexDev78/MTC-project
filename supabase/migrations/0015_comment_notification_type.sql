-- New `notification_type` value for product comments — sent to the
-- supplier when a client posts a top-level question, and back to the
-- client when the supplier (or another client) replies to it (see
-- `CommentController._notifyAboutComment`). `alter type ... add value`
-- cannot run inside the same transaction as a later statement that uses
-- the new value, but this migration only adds the value — nothing else
-- needs it yet.
alter type public.notification_type add value 'new_comment';
