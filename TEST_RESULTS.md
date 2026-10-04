# Bella verification — 4 October 2026

- 23 inherited frontend automated tests pass.
- Production Vite build passes.
- 56 live rollback SQL assertions pass against Bella. Fixtures are synthetic and rolled back. Coverage: cart quantities/stock, checkout validation/idempotency/server totals, failed transaction preservation, order transitions/manual payments/cancellation restocking/history, historical product deletion protection, customer and admin support, conversation isolation/selected replies/unread counts, review pending/spam/approval/ratings, metadata privilege denial and verified-email owner bootstrap.
- No database-schema warning/error security-advisor findings. Three INFO notices are deliberate private tables with no client policies. The later Auth advisor reports leaked-password protection disabled; this Auth setting is outside the connector's configuration capabilities.
- Authenticated HTTP integration checks pass: disposable admin/customer password login, role separation, denied customer product/category uploads and product save, admin upload/save, public variant/image retrieval, fresh-client persistence, price tampering denial, hidden drafts, category photo persistence, permanent deletion/storage cleanup. Instagram admin status succeeds and guest admin access is denied.
- All synthetic products, product storage objects and QA accounts were removed; five editable beauty categories with decorative photos remain.

Limits: browser QA unavailable; actual owner email confirmation and password-recovery email delivery not verified; Instagram connection and synchronization not verified; original newsletter remains disconnected. Original clothing backend and all real customer/account data were untouched.

`tests/bella-commerce-regression.sql` runs only synthetic rollback fixtures in Bella. `tests/bella-product-flow.mjs` requires disposable new-project QA credentials via stdin; never use real owner passwords. The unmodified inherited tests retain historical source references and must not be run against the clothing backend as part of Bella setup.

## Demo and animation update

- 25 frontend automated tests pass (23 inherited + two lifecycle tests for fairy idle scheduling, finite animation lifetime, reduced motion, hidden tabs and cleanup).
- Production Vite build passes with the supplied ZIP styling and new motion.
- Live SQL verification: ten published demos per existing category, two featured per category, 50 total products, 100 variants and 50 image records.
- All bundled photo paths and canonical product-folder paths validated locally.
- No schema, RLS, owner membership or Auth account changes were made for demo seeding. A proposed temporary privileged uploader was rejected by automatic approval review; demo data was added without creating that account.
- Browser visual/interaction QA remains unavailable. The new first-edit demo-photo ingestion has source/build validation, not a new authenticated browser test. Prior owner/Instagram/email activation limitations still apply.

## Beauty animation enhancement — 4 October 2026
- 27 frontend tests pass; production build passes.
- Canvas lifecycle checks cover idle sleep, finite scroll/hover effects, high-DPI cap, event listener cleanup, hidden-tab cancellation, reduced motion, excluded form targets and touch-hover suppression.
- Hero ornaments use finite CSS animation runs and IntersectionObserver/visibility pausing. Magic off disables new decorative layers and persists in local storage.
- Native SVG/canvas/CSS only; no dependency, catalog, authentication, admin, database or storage changes.
- Browser visual/interactive QA was unavailable; responsive positions and stacking were checked in source only.

## Packaging gradient update — 4 October 2026
- All 27 frontend tests pass, including idle/cancellation and finite hover/scroll effects with the new petal particles.
- Production build passes; generated background is included in public assets.
- Source check: storefront-scoped gradient CSS, pointer-inert decorations, finite animation runs, mobile positions, persistent Magic off and reduced-motion exclusions.
- No Supabase, catalog, admin or commerce workflow changes.
- Background imagery was visually inspected; full rendered browser QA is unverified because the supported browser capability is unavailable.

## Background placement correction — 4 October 2026
- 27 automated frontend tests pass; production build passes.
- Hero packaging background, multiply blending and hero decoration component removed.
- Card/caption/form backgrounds made opaque; fixed fairy canvas moved behind page content.
- Existing commerce/admin/backend logic unchanged.
- Full browser visual QA unavailable; CSS layering and exclusions reviewed in source.
