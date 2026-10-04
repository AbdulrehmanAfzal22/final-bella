# Maison Élan source handoff — updated 2026-09-25

This is the in-progress React + Vite storefront, **not the published site**. No credentials beyond the public anon/publishable key are included.

- Existing Site URL: https://maison-elan-fashion.talhazahidhussain0.chatgpt.site (behind its platform's own sign-in gate; returns 401 to plain fetches — this is NOT customer auth, don't treat it as such)
- Sites project ID: `appgprj_6ab37721b1b48191ac0dc09c9d623ad3`
- Supabase project: `cloth-web`, ID `oapkgdvsnpakpackmgcs`, region `ap-south-1` — this is the ONLY Supabase project for this app. Never create a new one.
- Nothing has been published to the live Site from this session.

## Database — verified live via Supabase MCP on 2026-09-25

Schema is fully built: `profiles`, `categories`, `products`, `product_images`, `product_variants`, `addresses`, `wishlists`/`wishlist_items`, `carts`/`cart_items`, `orders`/`order_items`/`order_status_history`, `admin_notes`, `reviews`, plus `private.admin_members`. RLS is enabled on every table. Storage bucket `product-images` exists (public read, admin-only write).

Server-side functions (all live, SECURITY DEFINER where needed): `is_admin()`, `save_product(payload)` (transactional product+variants+images save), `add_to_cart`/`set_cart_quantity`/`remove_from_cart`, `process_checkout(shipping, shipping_cents)` (atomic, row-locks stock, server-computed totals), `set_order_status`.

Applied migrations (do not reapply): `20260923144917` (commerce_foundation), `20260925073518`, `20260925073530` (the schema/functions/RLS above — these are NOT reflected in any local `.sql` file in this ZIP; the local `supabase/migrations/*.sql` files are stale/superseded, treat the live DB as ground truth over them). `supabase/migrations/20260923145824_commerce_transactions.sql` is empty and was never applied — safe to delete.

**Fixed this session:** `order_items_read` and `order_status_history_read` RLS policies previously only checked that the parent order existed (not ownership) — any signed-in customer could read any other customer's order contents. Both were tightened to `owner OR admin`, matching `orders_read`. Verified live.

**Admin:** `abdulrehmanafzal60@gmail.com` is now the store-owner admin (added to `private.admin_members` this session, confirmed by the account owner). The 3 QA fixture users (`qa-<uuid>@example.invalid`) and the QA admin membership are still present — owner said "review and decide later," so **do not delete them without asking again**.

Products/categories: zero rows. The store has no real inventory yet — this is the top of the remaining work.

## Code status

Storefront (home/shop/product/search/collections/cart/wishlist/checkout/orders/order-confirmation/account) and admin (products/categories/orders/customers/inventory/analytics) are implemented and their Supabase calls match the live schema/RPCs — verified by reading both sides, not assumed from docs. `npm run build` passes clean.

**Removed this session as dead code** (no gateway was ever wired, nothing imported them): `src/services/payment.js`, `src/services/secureCheckout.js`, `src/pages/PaymentStatus.jsx` + its route, `src/services/products.js`, `src/services/inventory.js` (both unused duplicates of `catalog.js`/`inventoryAdmin.js`). Checkout is intentionally **manual/COD**: `process_checkout()` creates an order with `payment_status = 'unpaid'`; no payment gateway is integrated. Owner chose this deliberately — wiring a real gateway (Stripe etc.) is a future decision, not a bug, unless they say otherwise.

Not yet verified end-to-end: the integration test at `tests/product-flow.mjs` is complete code but was never run to a passing result (it needs network access to `*.supabase.co`, which this sandbox doesn't have — run it locally with `node tests/product-flow.mjs` piping a fixture JSON of `{admin, customer, password}` QA ids to stdin). Reviews UI is implemented but not manually walked through. `docs/PHASE*.md` files describe more "completed" phases than the code actually supports in places — don't trust them over the live DB/code without re-checking.

Use `npm ci` and `npm run build` from the project root. `.env.example` contains only the public URL + publishable key (safe to expose, like an anon key) — never put a service-role key in the browser or commit one anywhere. This ZIP omits `node_modules`, `.git`, `dist`, and any `.env` files.

## Immediate next steps (in order)
1. Add real products/categories through `/admin/products` (schema/RPCs are ready and tested via RLS policy inspection — do a manual create→publish→view-in-shop pass to be sure).
2. Decide on payment: stay COD, or wire a real gateway (needs owner-provided API keys — do not fabricate credentials).
3. Run `tests/product-flow.mjs` locally against the live project to get an actual pass/fail.
4. Manual QA pass: signup→browse→cart→checkout→order history, then the same as admin.
5. Decide what to do with the 3 QA users / QA admin membership.
6. Only then: build, and publish to the SAME existing Site (`appgprj_6ab37721b1b48191ac0dc09c9d623ad3`) — do not create a new site.
