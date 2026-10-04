ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

UPDATE public.categories
SET description = coalesce(description, ''),
  is_active = coalesce(is_active, true);

ALTER TABLE public.categories
  ALTER COLUMN description SET DEFAULT '',
  ALTER COLUMN description SET NOT NULL,
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN is_active SET NOT NULL;

CREATE INDEX categories_active_display_order_idx
  ON public.categories(display_order, name)
  WHERE is_active;