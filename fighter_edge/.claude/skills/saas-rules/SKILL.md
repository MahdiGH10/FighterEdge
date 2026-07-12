---
name: saas-rules
description: Security checklist and best practices for vibe-coded SaaS apps (Next.js + Supabase + API-key-based backends). Use when writing or reviewing any API route, database table/RLS policy, auth flow, form handler, or anything touching user data, secrets, or payments. Also use before any deploy to production, before making a repo public, and whenever the user says "security check", "is this safe to ship", "review this route/endpoint", or "audit this".
---

# SaaS Security Review

You are reviewing or writing code for a real SaaS product, not a demo. AI-generated
code optimizes for "it works," not "it's safe" — it will produce a working feature that
has no auth check, no RLS policy, or a hardcoded secret, because none of those things
stop the happy path from working. Your job in this skill is to catch that class of bug
BEFORE it ships, not after.

Treat this as a hard gate for anything touching: authentication, authorization,
database access, user data, secrets/API keys, payments, or public-facing input.
Cosmetic/UI-only changes don't need this.

## How to use this skill

1. Identify what changed or what you're about to write: does it touch auth, the
   database, a public API route, a secret, or user input? If yes, work through the
   relevant sections below before considering the task done.
2. Don't just check that the feature demo works. Actively try to break your own
   assumptions (see "Verification, not just review" below).
3. If you find an issue, fix it and say so explicitly — don't silently patch and move
   on. The user needs to know what was wrong.
4. If AI-generated code "fixed" a bug by disabling a security check (turning off RLS,
   wildcarding CORS, commenting out an auth guard, catching and swallowing an auth
   error) — that is not a fix. Flag it and find the real cause.

---

## 1. Authentication & Authorization (the #1 vibe-coding failure)

- [ ] Every API route that touches user data has an explicit auth check
      (`if (!session) return 401` or equivalent) — not just "the frontend hides the
      button."
- [ ] Authorization is checked separately from authentication: does this *specific*
      user own/have permission for *this specific* record? Being logged in is not the
      same as being allowed.
- [ ] Watch for IDOR (Insecure Direct Object Reference): an endpoint like
      `/api/leads/:id` or `/api/sites/:id` must verify the record belongs to the
      requesting user, not just that some user is logged in. Test this by trying to
      fetch another account's resource ID while logged in as a different user.
- [ ] Server actions / API routes never trust a `user_id`, `business_id`, `role`, or
      similar field sent in the request body. Identity and role come from the
      server-side session, always.
- [ ] Admin/privileged actions (deleting data, changing plans, impersonation) have
      their own explicit role check, not just "logged in."

## 2. Database-level protection (Supabase / Postgres)

- [ ] Row Level Security (RLS) is enabled on every table from the moment it's created
      — Supabase tables are reachable over the API by default until RLS is turned on.
      This is easy for an agent to skip because the demo works fine without it.
- [ ] RLS policies check ownership (e.g. `auth.uid() = user_id`), not just
      "authenticated users can read/write."
- [ ] Test RLS policies by actually querying as a second, different user — don't just
      read the policy and assume it's correct.
- [ ] The Supabase **service role key** (which bypasses RLS entirely) is only ever
      used in server-side code (API routes / edge functions) — never shipped to the
      browser bundle, never used in client components.
- [ ] Foreign key relationships and cascade deletes are deliberate, not accidental data
      loss waiting to happen.

## 3. Secrets management

- [ ] No API keys, DB URLs, or service role keys are hardcoded in source files or
      client-side code. Check for this explicitly — it's a common "just to test it"
      shortcut that gets forgotten.
- [ ] Secrets live in `.env.local` / environment variables, and `.env*` is in
      `.gitignore` **before the first commit**, not after.
- [ ] Any secret that ever touched a public repo (even in a since-deleted commit) is
      treated as compromised and rotated — git history retains it.
- [ ] Client-exposed env vars (e.g. `NEXT_PUBLIC_*`) are checked to confirm they truly
      contain nothing sensitive — it's easy to prefix the wrong variable.

## 4. Input validation & injection

- [ ] All user input is validated server-side, even if client-side validation also
      exists. Client validation is UX, not security — it's trivially bypassed.
- [ ] Database queries use parameterized queries / the ORM's query builder — never
      raw string-concatenated SQL.
- [ ] Any user-generated content that gets rendered back to other users (business
      descriptions, reviews, comments) is escaped/sanitized against stored XSS.
- [ ] File uploads (if any) are validated for type/size server-side and never trusted
      based on client-reported MIME type or extension alone.

## 5. Rate limiting & abuse prevention

- [ ] Public-facing forms, auth endpoints (login, signup, password reset), and any
      route that calls a paid external API (Anthropic, email/SMS/WhatsApp senders) has
      rate limiting before it's exposed to the public internet.
- [ ] Scraping/outreach pipelines have their own throttling so a bug or abuse can't
      blow through an API budget or get an account banned by a third-party platform.
- [ ] Consider CAPTCHA or similar on public signup/contact forms if abuse is a
      realistic risk for this product.

## 6. Dependency & AI-generated code hygiene

- [ ] Run the project's dependency audit (`npm audit` or equivalent) periodically, not
      just at project start.
- [ ] Any AI-generated code touching auth, payments, or data access is read line-by-line
      before merging — not just verified by running the happy-path demo.
- [ ] New dependencies introduced by an agent are sanity-checked (is this a real,
      maintained package? does it need this level of access?) before install.

## 7. CORS & security headers

- [ ] CORS is locked to the actual frontend domain(s) — never `*` — once any route
      handles authenticated or sensitive data.
- [ ] Basic security headers are set (CSP, `X-Frame-Options`, `X-Content-Type-Options`)
      via `next.config.js` or middleware before production launch.

## 8. Logging & error handling

- [ ] Production error responses to the client are generic (no stack traces, no raw DB
      error messages, no internal file paths).
- [ ] Detailed errors are logged server-side only.
- [ ] Auth failures and unusual access patterns (e.g. repeated 401s/403s from one
      source) are logged somewhere actually monitored, not just to a console that
      nobody reads.

## 9. Payments (if/when applicable)

- [ ] Payment processing goes through a provider (Stripe, etc.) — never handle raw
      card numbers, bank details, or CVVs in your own code or database.
- [ ] Webhook endpoints from payment providers verify the signature before trusting
      the payload — don't act on an unverified webhook body.
- [ ] Prices and entitlements are enforced server-side; never trust a client-supplied
      price or plan.

---

## Verification, not just review

Reading the code and nodding is not enough. Where practical, actually try to break it:

- Log in as User A, grab an object ID that belongs to User B, and try to fetch/modify
  it directly via the API.
- Try hitting an endpoint with no session token at all.
- Check whether a "hidden" admin route is actually protected or just not linked in the
  UI.
- Try a request with an unexpected/malicious field in the body (e.g. `role: "admin"`)
  and confirm it's ignored server-side.

## Output format when reviewing existing code

When asked to run this skill against existing code, report findings as:

- **Critical** — exploitable now (missing auth, RLS off, exposed service key, IDOR)
- **Important** — should fix before real users touch it (no rate limiting, weak input
  validation, missing security headers)
- **Minor / hardening** — good practice but not urgent (logging improvements, dependency
  updates)

End with a one-line verdict: safe to ship, needs fixes before shipping, or needs a
deeper pass.
