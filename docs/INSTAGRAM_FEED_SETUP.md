# Instagram Reel Feed Setup

The homepage feed uses Instagram's official Instagram Login API (currently Graph API v25.0). It never scrapes Instagram pages or downloads/re-hosts Reel videos. Until the Meta app is configured and the account is authorized, the storefront displays its Instagram follow fallback.

## Requirements

- A Meta developer app configured for Instagram API with Instagram Login.
- The `@bellabyrt` Instagram account must be eligible for Instagram Login and public API access (professional account requirements and Meta review/access requirements apply).
- Supabase CLI access to this project.

## Configure Meta

1. Add the Instagram API with Instagram Login product to the Meta app.
2. Add this exact OAuth redirect URI to the Instagram Login allowlist:

   `https://oapkgdvsnpakpackmgcs.supabase.co/functions/v1/instagram-feed?action=oauth-callback`

3. Enable the `instagram_business_basic` and `instagram_business_manage_insights` permissions as allowed for the app. Insights are optional; the feed still syncs if individual view metrics are not available.

## Deploy Supabase

From the repository root, apply migrations and deploy the edge function:

```sh
supabase db push
supabase functions deploy instagram-feed
supabase secrets set META_APP_ID=<Meta-app-id> META_APP_SECRET=<Meta-app-secret>
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are provided to hosted Supabase Edge Functions. Never add the Meta app secret or Instagram access token to frontend environment variables. The access token is stored in a table with RLS enabled and no browser-role grants; only the edge function's service role can access it.

## Connect And Configure

1. Sign in as a Maison Élan administrator and open `/admin/instagram-reels`.
2. Save the `@bellabyrt` profile settings and choose display, autoplay, and card-count settings.
3. Select **Connect Instagram** and authorize the intended account. The callback verifies its username is exactly `bellabyrt`.
4. Select **Refresh Instagram Feed**. The function syncs the newest public video posts whose official permalink is a Reel, plus available captions and counters.

The API response is cached for one hour. A stale cache is refreshed on the next storefront feed request, or immediately with the admin refresh control. Each storefront request receives at most 12 cached Reels; **Load older Reels** fetches the next page. The configured cache limit is capped at 50 records.

The view count is requested through Instagram media insights for up to the newest 12 Reels and is omitted when Meta does not return it. No engagement figures are inferred or fabricated.
