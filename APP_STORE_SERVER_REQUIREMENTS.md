# Wicchu: server requirements for App Store review

Date: 2026-09-29

## Purpose and current status

Implement and deploy the server support needed for account deletion, Sign in with Apple, personal user blocking, and a dedicated reviewer account. Return the confirmed API contract so the Flutter client can be integrated and tested.

**All new routes in this document are proposals, not claims that these endpoints exist.** Reuse equivalent existing routes if available and document their exact request/response contract. This repository contains the Flutter client, not the Hexora server.

Current production origin: `https://hexora.dev`.
App: `Wicchu`; iOS bundle ID: `com.wicchu.wicchu`; Apple team ID: `P3F322KYHU`.

Existing client integration:

- Authentication: `/api/auth/login`, `/register`, `/google`, `/facebook`, `/refresh`, `/logout`.
- Authenticated community APIs: `/api/community/v1/...`.
- Post reports and administrator moderation/member bans already have client support. Personal user blocks are a separate feature.
- Account deletion currently opens a web page; no deletion operation exists in the client's `AuthGateway`.
- Apple login is not implemented in the client yet.
- Build 1.0.0 (11) was uploaded, but has not been submitted for review.

## 1. Shared API requirements

- Derive the acting user from a validated bearer session. Never trust a submitted acting-user ID.
- Follow existing JSON error format: `code`, `message`, `requestId`, optional `fieldErrors`.
- Use stable machine-readable codes; messages must not expose tokens, passwords, private keys, or another user's private identity.
- Rate-limit sensitive routes; audit actions without storing authentication secrets.
- Use UTC ISO-8601 timestamps and opaque pagination cursors.
- Document authorization rules, status codes, example JSON, retry/idempotency behavior, and deployed version.
- Successful responses should be JSON objects or empty responses, consistent with `AuthenticatedApiClient`.
- Keep existing clients compatible. Publish the confirmed contract before wiring the new client flows.

## 2. Account deletion — release blocker

### User experience to support

Settings → Delete account → explain consequences → fresh verification → explicit confirmation → server accepts deletion → local session is cleared.

Deletion must work for email, Google, Facebook, and Apple accounts, including accounts without a password. An email-to-support-only flow is not the intended implementation.

### Proposed routes

| Route | Purpose |
| --- | --- |
| `GET /api/community/v1/me/deletion-preview` | Return account ownership conflicts and a safe summary of what will be removed |
| `POST /api/auth/reauthenticate` | Verify a fresh password or provider credential; issue a short-lived proof scoped to account deletion |
| `POST /api/community/v1/me/deletion` | Confirm and initiate deletion using the proof |

Example initiation request:

```json
{
  "confirmation": "DELETE",
  "reauthenticationToken": "<short-lived proof>"
}
```

Use an `Idempotency-Key` header. Bind the proof to the current user, session and deletion purpose; enforce expiration and replay protection. Reauthentication payloads must be provider-specific and documented. Never require a social-login user to provide a nonexistent password.

Example response for asynchronous deletion (`202`):

```json
{
  "status": "pending",
  "requestedAt": "2026-09-29T12:00:00Z",
  "completionExpectedBy": "2026-10-29T12:00:00Z"
}
```

The date above is illustrative: return the actual operational deadline. Use `200` with `status: "deleted"` only when deletion is complete. The client must distinguish accepted/pending from completed.

### Server behavior

- Durably record/enqueue the request before acknowledging it.
- Revoke all access/refresh sessions immediately after acceptance; enforce revocation even for otherwise unexpired access JWTs.
- Remove push tokens and stop email/push/socket activity for the account.
- Delete or irreversibly anonymize personal profile data, provider identifiers, memberships, follows, saves, reactions, comments, posts and media according to documented policy.
- Handle shared content, moderation records, backups and legally required retention explicitly. Do not promise deletion of records that must be retained.
- Revoke Sign in with Apple tokens when applicable; retry provider failures securely. Do not let a transient provider outage silently cancel an accepted deletion.
- Queue workers must be idempotent, retried and observable; avoid restoring deleted data through a later backup restore.
- Define whether a later signup creates a genuinely new account. It must not silently resurrect deleted data.
- Confirm completion through a documented channel without preserving unnecessary personal data.

### Ownership conflicts

Do not silently delete other users' communities or businesses. Return a `409 OWNERSHIP_TRANSFER_REQUIRED` with the spaces the requester owns and allowed resolution actions. Support transferring ownership or an explicitly confirmed, authorized space-deletion flow. Make the resolution reachable so sole ownership cannot permanently prevent account deletion.

### Required tests

- Valid deletion for every supported login provider.
- Reauthentication failure, expired proof, replay, and cross-user proof rejection.
- Duplicate/retried request returns consistent state.
- Database/queue failure does not falsely report acceptance.
- All sessions fail after acceptance; other users remain unaffected.
- Sole-owner conflicts and successful resolution.
- Worker cleanup of media, notifications and linked data; retries and retention exceptions.

## 3. Sign in with Apple — release blocker

Add an equivalent privacy-preserving login alongside Google/Facebook. Native client implementation follows once the server contract and Apple configuration are confirmed.

### Proposed routes

- `POST /api/auth/apple/challenge`: return a short-lived, single-use challenge bound to an authentication attempt.
- `POST /api/auth/apple`: verify native Apple authorization and issue the existing Wicchu session format.

Suggested challenge response:

```json
{
  "challengeId": "opaque-id",
  "nonce": "cryptographically-random-value",
  "expiresAt": "2026-09-29T12:05:00Z"
}
```

Confirm the nonce convention: the native client sends SHA-256 of the raw nonce to Apple; the server verifies the identity token's nonce against that expected digest and consumes the challenge. Do not mix raw and hashed values.

Suggested login request:

```json
{
  "challengeId": "opaque-id",
  "identityToken": "<Apple JWT>",
  "authorizationCode": "<Apple authorization code>",
  "givenName": "Optional first-login name",
  "familyName": "Optional first-login name"
}
```

Successful response must match existing auth responses:

```json
{
  "accessToken": "<Wicchu access token>",
  "refreshToken": "<Wicchu refresh token>",
  "userId": "stable-user-id",
  "userName": "display-name",
  "isNewUser": true
}
```

### Verification and identity rules

- Validate JWT signature using Apple JWKS with safe key rotation; reject unexpected signing algorithms.
- Verify issuer, exact allowed audience, expiry, nonce/challenge and authorization-code exchange.
- Native iOS audience is `com.wicchu.wicchu`. Add web/Android service IDs only if those flows are implemented.
- Use verified provider + Apple `sub` as the account identity. Do not identify users solely by email.
- Accept private relay email. Persist first-login name/email when supplied; later sign-ins may omit them.
- Never automatically link accounts based only on an untrusted email claim. Linking to an existing account requires proof of ownership through an explicit flow.
- Enforce deleted/disabled/banned account policies consistently across all login providers.
- Use server-side Apple authorization-code exchange and encrypted token storage where needed for revocation.
- Do not log identity tokens, authorization codes, client secrets or refresh tokens.

### Apple configuration required from the account owner

- Enable Sign in with Apple on the `com.wicchu.wicchu` App ID.
- Apple team ID, Sign in with Apple Key ID and signing `.p8` held only in server secret storage.
- Configure relay email sender domains if emailing relay users.
- Regenerate provisioning profiles after enabling the capability.
- Apple server notifications/token revocation handling where applicable.

**The Sign in with Apple key is different from an App Store Connect metadata API key. Neither belongs in Flutter assets or git.**

### Required tests

Valid first/repeat login; missing name/email; private relay; expired/wrong issuer/wrong audience token; invalid signature; reused code/challenge; nonce mismatch; account collision; revoked/deleted account; Apple key rotation/outage. Client cancellation must not create a session.

## 4. Personal user blocking — release blocker

Community administrator bans do not replace an individual's ability to block an abusive user.

### Proposed routes

| Route | Response |
| --- | --- |
| `GET /api/community/v1/me/blocked-users?cursor=...&limit=...` | `{ "items": [...], "nextCursor": null }` |
| `PUT /api/community/v1/me/blocked-users/{targetUserId}` | `{ "blocked": true }` |
| `DELETE /api/community/v1/me/blocked-users/{targetUserId}` | `{ "blocked": false }` |

Each list item should include only safe display information: `userId`, `name`, optional `avatarUrl`, and `blockedAt`. PUT and DELETE must be idempotent. Prevent self-blocks; enforce that callers can only modify their own block list.

### Enforcement and visibility

- Define and document the product policy for both directions of a block. At minimum the blocker must stop seeing/interacting with the blocked user's content and must not receive their targeted interactions.
- Enforce on the server, not just via a client-side filtered list.
- Apply consistently to following/community/category/profile/saved/search feeds, post detail/deep links, comments, mentions, notifications, real-time events and any messaging routes.
- Filter before pagination, with reliable cursors and counts; do not expose hidden content through alternate queries or cached responses.
- Reject new prohibited interactions with a stable code such as `INTERACTION_NOT_ALLOWED` without unnecessarily revealing who blocked whom.
- Decide what to do with prior follows, existing notifications, shared groups and role-based moderation access. Document any narrow moderation exception.
- Blocking must not grant/remove administrator roles or silently leave communities.
- Anonymous posts must not expose real author IDs. If blocking anonymous authors is supported, use an opaque server-resolved content-target route and preserve anonymity in responses/listing. Otherwise provide reporting and document the limitation.
- User block actions must work across devices. Client refresh/cache invalidation follows successful server changes.

### Required tests

Block/unblock/retry; self-block; cross-user authorization; feeds and comments; deep links; pagination; notification/socket delivery; anonymous identity protection; moderator exceptions; public profile content; persistence across sessions/devices.

## 5. Dedicated App Review account and content

Create only after the owner supplies an approved email inbox or authorizes backend-admin provisioning.

- Use an ordinary dedicated account, not the owner's account or a global administrator.
- Generate a strong password and store it outside git; deliver securely for App Store Connect reviewer fields.
- Ensure email verification is completed through an authorized process. Do not add a public verification bypass or a hard-coded reviewer password.
- No special hidden behavior keyed to reviewer accounts, devices, IPs or review dates.
- Give access to clearly labeled sample communities and a sample public profile with non-sensitive content. Include ordinary membership and a limited managed sample space so reviewers can exercise both flows.
- Make posts, categories and rules available; use owned/licensed media and invented sample identities, not real private users.
- Keep the backend live throughout review. Ensure sample-account deletion can be tested; provide an approved reset/reprovision process if necessary.
- Return email, verification state, sample space identifiers and tested feature paths. Keep password delivery separate from documentation/source control.

## 6. Public pages and privacy information

Owner confirmed privacy URL: `https://hexora.dev/wicchu/privacy`.
Owner supplied support URL: `https://hexora.dev/wicchu/support`.

At the last check, the support URL returned a branded "Page unavailable" response. Publish a real support page with contact details. A draft is at `release/app-store/support.html` in the Flutter repository.

- Align the privacy/deletion pages with deployed functionality, retention and service providers.
- Existing Hexora deletion page instructs users to email support. Update it once self-service deletion exists.
- Clarify collection of account identifiers, user content/media, location, push tokens, usage and diagnostics.
- Confirm Google/Facebook/Firebase SDK data use and any tracking/advertising behavior.
- Document third-party moderation/AI processing, data sent, retention and any required consent flow.
- Provide factual answers for App Store privacy and age-rating declarations; frontend code alone cannot establish server behavior.

## 7. Existing server rules to verify during release testing

- Business/public-profile followers cannot create or edit posts merely because they follow the page. Enforce owner/admin authorization server-side, independent of Flutter controls.
- Community publishing, rules acceptance, approval requirements and banned-account restrictions remain enforced.
- Report/moderation queues and content filtering operate in production with a documented response process.
- Push delivery must be tested against a distribution-signed iOS build after confirming APNs entitlements and provider configuration.

## 8. App Store Connect metadata access — separate owner task

This is **not an application backend endpoint** and not required for user login.

To automate listing metadata, screenshots and review submission, configure an App Store Connect API key with suitable app-management permissions. An individual key can scope access through its user's app permissions; team keys apply across apps. Use the least access needed.

Provide locally, outside git:

- Private `.p8` file path.
- Key ID.
- Issuer ID for a team key; specify when using an individual key instead.
- App access/role and Wicchu's App Store Connect app ID if known.

Do not send the private-key contents in chat or place them in Flutter/server public assets. Verify access with a read-only API request before modifying metadata. Apple agreements, legal declarations and final submission approval remain owner-controlled.

Owner-approved launch preferences: free, Americas and Europe. Exact storefront list and mandatory regional declarations still need final confirmation.

## 9. Deliverables needed back from the server developer

1. Backend repository location and branch/commit containing the implementation.
2. Confirmed OpenAPI or equivalent contract for each route, with examples and errors.
3. Database migrations/indexes and rollout/backfill instructions.
4. Staging URL, then production deployment confirmation.
5. Automated test results covering authorization, deletion jobs, provider verification and block enforcement.
6. Apple configuration checklist completion; no secret values in the handoff.
7. Reviewer-account provisioning result and secure credential handoff.
8. Public support/privacy/deletion page URLs and privacy/retention answers.
9. Operational notes for deletion failures, moderation handling, token revocation and rate limits.

Client integration, release testing, replacement IPA upload and review submission remain pending those deliverables. Do not represent proposed endpoints as deployed or these requirements as already satisfied.

## References

- Apple App Review Guidelines, sections 1.2, 4.8 and 5.1.1: https://developer.apple.com/app-store/review/guidelines/
- Account deletion: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- App Store Connect API access: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api
