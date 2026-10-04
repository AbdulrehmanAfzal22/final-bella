# Bella by RT — 4 October 2026

Bella retains the complete supplied React application: storefront, original routes, admin dashboard, categories and accessories, products and variants, inventory, customers, order management, analytics, reviews, wishlist, cart, checkout, account and contact support. The original cloth-web project is unchanged. Presentation uses cream, blush and rose with beauty photography.

## Backend

A separate Supabase project `bellabyrt` is active in Mumbai. Project reference: `bpedttjsbmuvtyqehvnx`. The frontend uses its browser-safe publishable key, never the old clothing backend. Both original Edge Functions (`instagram-feed` and `delete-product`) are deployed.

32 actual applied clothing-backend migrations were replayed into this fresh project. RLS, storage, commerce RPCs, admin authorization, stock locking, order history, payment records and moderation are retained. No real clothing customers, accounts, passwords, orders, catalog products, photos or Instagram tokens were copied.

The ZIP and deployed clothing backend were not fully consistent. Bella preserves the deployed request/reply support tables and subject grouping, with compatibility RPCs for the ZIP's selected-conversation replies, unread counters and mark-read actions. Review submission uses the existing receipt RPC so pending reviews do not require forbidden SELECT access. The unused legacy support adapter names the actual `support_messages` table. Instagram shows a clean empty state until the account is connected.

## Owner setup still required

Register at `/register` using `abdulrehmanafzal60@gmail.com`, choose your new password, and verify your email. The trusted database trigger grants admin membership only after that selected email is verified. Editable user metadata does not grant admin. Then sign in and open `/admin`.

Supabase Authentication URL Configuration must allow the deployed Site URL, `/login` and `/reset-password` redirects. The connector does not expose those settings; email delivery, actual owner confirmation and password-recovery delivery have not been verified. Configure production SMTP before a public customer launch if Supabase's default email limits prevent customer delivery.

Instagram requires the owner's Meta app credentials in Edge Function secrets (`META_APP_ID`, `META_APP_SECRET`) and an authorized Instagram connection. Configure the callback shown by the original integration, then use Admin → Instagram Reels → Connect. No old Instagram secret was transferred. Real sync remains pending.

Upload your actual Bella products, prices, stock and photos in Admin. Decorative AI imagery is used for the hero/category artwork; it does not represent real stock or purchasable products. Categories are initial editable beauty taxonomy. Fifty explicitly requested demo products now populate the preview catalog; sample names, prices and stock are marked Demo.

The original newsletter is an explicitly disconnected placeholder. It was retained to match the supplied logic; no mailing list or marketing delivery is claimed. USD, free shipping and cash-on-delivery/manual payment logic remain the same as the original source.

## Run locally

Use Node.js 22.12+:

```sh
npm ci
npm run dev
```

Optional `.env` overrides: `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`, both for Bella only. Vite embeds them at build time.

## Database source

For a future empty project, apply `supabase/bellabyrt-source-schema.sql`, then `bella-instagram-extension.sql`, `bella-support-compatibility.sql`, and `bella-owner-bootstrap.sql` in that order. Do not reapply to the existing Bella project. `supabase/source-history/` is the read-only original applied history. `supabase/migrations/` is retained historical ZIP material and is not a complete verified fresh-project sequence.

## Verification and limits

See `TEST_RESULTS.md`. Production build and inherited frontend checks pass; live database tests cover stock, checkout, authorization, order history, support, reviews and owner role verification. Browser visual/interaction QA was unavailable in this managed session. Actual owner email, recovery delivery and Instagram sync remain unverified. This is not a claim of 100% production launch readiness.

## Demo catalog and fairy motion update

The supplied Bella_by_RT ZIP's newer logo, admin/account colors, footer, accessories and newsletter styling are preserved. Each of the five existing categories has ten explicitly labeled demo products: 50 products, 100 variants, 50 image records. Two items per category are featured; the New Arrivals carousel displays those ten featured products. Sample USD prices and stock are preview content. Original cart, wishlist, checkout, support and admin authorization remain in place.

`data/demo-catalog.json` records the demo identities and content. `supabase/bella-demo-catalog-seed.sql` is an idempotent DML seed, not a schema migration; it creates missing demos without resetting existing demo edits or stock. Never run it against cloth-web.

Demo photos are bundled under `public/assets/demo/`, and `src/lib/demoImages.js` resolves only the seeded demo media paths to those assets. On the first admin edit that retains a demo photograph, the existing authenticated Storage upload flow copies that photograph into the product's own folder before the original save RPC validates it. Real uploaded media continues using Supabase Storage. No Auth account or admin membership was created to seed this catalog.

Scroll activates a brief blush/gold fairy flight with separate sparkling dust; there is no continuous trail line. The Magic on/off button stores the visitor's preference locally. The effect honors reduced motion, stops in hidden tabs and stops scheduling frames after the particles fade. It is decorative and does not intercept clicks. Fairy magic is restricted to storefront layouts, keeping admin workspaces clear.

## Beauty animation update — 4 October 2026

The storefront now has a coordinated blush, pearl and gold motion treatment. The hero has six native vector heart/star/butterfly ornaments and two pearl accents with finite animation runs, paused outside the viewport and in hidden tabs. The scroll fairy has larger translucent wings, a gradient dress, gold accents, slower curved flights, floating hearts and an occasional companion butterfly. Product/category/hero-link pointer entry or deliberate touch creates a short sparkle bloom; there is no continuous cursor or scroll line. Product imagery has a single gloss sweep and a gentle lift on hover, with small heart and colour-swatch interactions.

Magic on/off persists the visitor's choice and stops the new decorative layers. Reduced-motion settings suppress the decorations automatically. The canvas renderer sleeps between effects and caps particles and pixel ratio. Commerce, support, authentication, catalog data and admin workflows were not changed. No database or Supabase project changes were required.

Verification: 27 automated tests pass, including hover/touch, hidden-tab, cleanup and reduced-motion checks; production build passes. Browser visual QA remains unavailable in this managed workspace.

## Packaging background update — 4 October 2026

The storefront background now follows the uploaded lip-gloss packaging: warm ivory blush (#fff1ef), pale pink (#f8dbe0) and rose washes (#efb5c8), with a subtle diagonal watercolour brush texture. The full storefront shell, hero, footer, public shop/category sections and account surroundings share the palette; product photos and form surfaces remain readable. The packaging reference itself and its printed text/QR were not placed on the website.

Added a finite, gently moving rose glow behind the page, four floating hero petals (two on mobile) and short canvas petal blooms on scroll and product interactions. Magic off and reduced motion disable the decorative additions; tab visibility pauses the glow. All catalog, admin and backend logic remains unchanged.

Validation: all 27 frontend tests pass and production build passes. Background asset inspected against the supplied packaging image; browser visual/interactive QA remains unavailable in this managed workspace.

## Background placement correction — 4 October 2026

The packaging theme is confined to page/section surroundings. The hero now uses its original clean background and normal image blending; the hero's decorative atmosphere was removed. Product, category, editorial, review and order cards, captions, forms, modal and support surfaces use opaque backgrounds to prevent the underlying pattern showing through. The previously plain authentication page surroundings inherit the same page texture while its form stays opaque. The fairy canvas now sits in the background stacking layer behind the content rather than above photos or text.

This correction supersedes the earlier hero texture/petal description. All 27 tests and production build pass. Browser visual QA remains unavailable; stacking and background placement were checked in source.
