# App Review fixes — implementation prerequisites

These are proposed contracts, NOT existing/verified backend endpoints. Do not ship buttons that pretend these operations succeeded. Implement against the actual backend repository and cover the server rules before enabling UI.

## Account deletion

- Provide an authenticated deletion initiation endpoint with fresh identity verification and explicit final confirmation.
- Return a clear completed or queued state; never sign out and claim deletion following a failed request.
- Revoke all sessions/device tokens; delete or anonymize posts/comments/uploads, memberships, reports, identifiers and profile data according to actual policy and lawful retention obligations.
- Resolve sole-owner communities/businesses explicitly (transfer or delete confirmation). No silent deletion of other users' spaces.
- Revoke Apple tokens when applicable; server-side keys stay on server.
- Client: Settings → Delete account → explain consequences → reauthenticate → confirm → await successful server response → clear local user state and return to login.
- Tests: unauthorized/other-user access, expired session, duplicate request, server failure retains session, owner conflicts, token revocation and subsequent login behavior.

## Apple login

- Enable Sign in with Apple for com.wicchu.wicchu; add entitlement and refresh provisioning profiles.
- Native Apple authorization with secure random nonce; exchange identity token, authorization code and nonce with backend.
- Server verifies Apple signature/JWKS, issuer, audience, expiry and nonce; use stable Apple subject as identity.
- Do not merge existing accounts solely by unverified email. Preserve initial name/email, support private relay.
- Server securely stores any refresh token required for later revocation. Never embed Apple signing keys in the Flutter app.
- Client must handle cancellation without logging in, server rejection without storing tokens, and deleted accounts.
- Keep existing Google/Facebook flows; add a qualifying privacy-preserving option instead of silently removing them.

## Personal user blocking

- Authenticated list/add/remove block endpoints scoped to current user; block target is a stable user ID.
- Server enforces blocking for feeds/search/direct post access/comments/notifications and interaction creation; prevent self-blocks and unauthorized management of another user's list.
- Define handling of existing memberships and public profile content; administrator bans are a different operation.
- Client: post/profile menu → Block user confirmation; Settings → Blocked users → unblock.
- After successful block refresh visible content and cached lists. Surface failures accurately; don't claim success with a local-only filter.
- Tests: persistence across devices, blocked content through deep links, comments, self-block, anonymous post author handling without revealing identity, unblock, unauthorized requests.

## Reviewer account

- Needs owner-supplied controlled email and email verification, or authorized backend admin provisioning.
- Dedicated ordinary account with populated review spaces; minimum permissions. No personal or admin credentials in review notes.
- Generate/store a strong password outside git; put it in App Store Connect reviewer login fields via authorized access.
- Verify the account works against the release backend, including rules acceptance and posting. No hidden review-only behavior or fake server success.

## App Store Connect access

An Xcode upload session does not supply a public API credential for metadata editing.
Owner must create/authorize an App Store Connect API key. Keep the .p8 in a private directory outside the repo; provide its path, Key ID and Issuer ID. Verify permissions with a read-only request before metadata writes. Final submission remains pending review of the finished listing.
