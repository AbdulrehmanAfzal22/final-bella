# Maison Élan Phase 6A — Supabase Security Audit

Scope:

## Database review checklist
- profiles access control
- products visibility rules
- product variants permissions
- cart ownership rules
- wishlist ownership rules
- orders customer/admin access
- addresses privacy rules
- reviews moderation rules

## Storage review checklist
Bucket:
product-images

Verify:
- customer upload prevention
- admin upload permission
- update/delete restrictions
- public read policy

## Required production checks
- Confirm RLS enabled on all user tables
- Confirm no service-role key exists in frontend
- Verify admin role is granted manually
- Test anonymous, customer, and admin permissions

No database policy changes are applied automatically in this package.
Live Supabase verification should be performed against the connected project.
