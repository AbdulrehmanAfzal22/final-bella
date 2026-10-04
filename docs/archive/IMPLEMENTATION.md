# Maison Élan upgrade

## Stage 1 audit
Original source: dist/index.html, dist/app.js and dist/styles.css; commit f1827f5e0a8ec7527c31f05cca86cc90d59015dd. Eight hard-coded products, fabricated account/orders/metrics, in-memory cart/wishlist, nonfunctional variants/admin controls. No customer authentication.

## Architecture
React + Vite + React Router. Custom CSS design tokens; storefront and administration layouts. Supabase Auth provides customer identity, separate from private Sites access. Database RLS enforces ownership and protected admin membership. Services own API access, Context owns session/cart state, pages own presentation. PostgreSQL RPCs handle atomic product saves, inventory and checkout. Only a publishable API key is shipped.

## Acceptance checklist
- [x] Inspect source and verify cloth-web (oapkgdvsnpakpackmgcs), initially empty.
- [ ] Versioned schema, RLS and Storage policies applied and audited.
- [ ] Customer authentication and protected admin access.
- [ ] Admin product with uploaded images/variants persists and displays after refresh.
- [ ] Search/filter/sort and correct variant selection.
- [ ] Persistent wishlist/cart with login-return selection.
- [ ] Atomic server-priced order creation, stock locking and immutable item snapshots.
- [ ] Customer order history and admin status management.
- [ ] Real metrics; no fabricated commercial data.
- [ ] Desktop/mobile/keyboard/security tests.
- [ ] Production build and existing-Site publication.

Storefront currency remains USD from the original prototype. Orders will explicitly remain unpaid; no gateway or payment success will be simulated. No fabricated catalog will be published. First real admin identity must be explicitly supplied/confirmed by the owner, never inferred from the first signup.
