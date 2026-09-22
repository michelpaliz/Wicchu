# Wicchu backend handoff: unfinished UI flows

This document began as an inventory of unfinished UI flows. Some flows have since been wired to HTTP endpoints; the inventory below still needs a full re-audit. The server lives elsewhere, so confirm its response contract against the Hexora server before treating a client flow as complete.

## Current integration

- `lib/main.dart` injects `HttpCommunityRepository`. Community creation resolves or registers the device's town through `POST /api/community/v1/towns/resolve`, then submits `POST /api/community/v1/communities` with the returned stable town ID. The form no longer depends on `GET /api/community/v1/towns` being populated. Authenticated creation still needs an end-to-end emulator verification.
- `FacebookAuthGateway` calls `POST /api/auth/facebook` at `API_BASE_URL` (default `https://hexora.dev`). The backend implementation is not in this repository. Android signing requirements are in `FACEBOOK_LOGIN_REQUIREMENTS.md`; end-to-end login has not been verified here.
- The README identifies `/api/community/v1` as the community API prefix. The app now calls routes for discovery, membership, feed, post detail, categories, reactions, comments, saves, reports, notifications, profile, and creation under that prefix. Authenticated server responses have not been verified in this workspace.
- Language and Light/Dark/System appearance choices already work locally and persist in device preferences. They do not need backend endpoints.

## UI gap inventory

| Screen / control | What happens now | Backend capability and Flutter wiring needed |
| --- | --- | --- |
| Login / Continue with Facebook | Client attempts the Facebook SDK exchange and calls `/api/auth/facebook`; no configured end-to-end sign-in in this repository | Verify token with Meta, return the session shape below, and add refresh/revocation endpoints. Client must refresh on startup and handle expired/revoked sessions. |
| Home / community card | Loads joined communities from the API and opens a community page | Verify authenticated data, member counts, and pagination. |
| Home / neighborhood feed, search, category chips | Loads posts and categories from the API; sends search text as `q` and filters visible categories locally | Verify server search and add pagination when the API contract is confirmed. |
| Home / New post | Opens the editor and submits through the repository | Verify authenticated post creation and approval status. |
| Explore / search | Sends `q` to the communities endpoint | Verify server search and add pagination when available. |
| Explore / community cards and Joined | Loads communities and calls join/leave endpoints | Verify membership responses, especially private-community requests. |
| Activity | Loads notifications, marks them read, and opens their posts by ID | Verify notification target IDs and the post detail response. |
| You / name, handle, counts | Loads the profile from the API | Verify server counts and refresh behavior. |
| You / My communities, My posts, Saved posts, Communities I manage | Opens API-backed collections; save and unsave call the API | Verify authenticated collections and pagination. |
| You / Settings, Help | Placeholder rows were removed; language and appearance remain local controls | Add dedicated pages only after their intended content is defined. |
| Community / Joined | Calls join/leave endpoints; Share and empty more-menu actions were removed | Verify membership state and define an invitation/deep-link contract before restoring sharing. |
| Community / categories and latest posts | Loads categories and posts from the API; refreshes after post creation | Verify server responses and pagination. |
| Category / Latest and Popular | Sends `sort=latest` or `sort=popular` when listing category posts | Verify sorting and pagination against the server. |
| Post card / tap, reactions, comments, saves, reports | Opens post detail and calls the corresponding API actions | Verify counts, permissions, and error responses. |
| Create post / Photo and Video | Picks files and uploads through the media endpoint | Verify upload limits and media response against the server. |
| Create post / Publish | Submits text, category, and media through the posts endpoint | Verify `published` and `pendingApproval` responses. |
| Create community / Create | Profile opens the form; the client submits the community to the HTTP API and refreshes profile, Home, and Explore after success | Verify authenticated server persistence, owner role, returned community ID, and category creation. |
| Create community / Approve posts before publishing | The switch value is included as `approvalRequired` in the create request | Verify the backend stores and enforces the policy when publishing posts. |
| Create community / Share invitation | Empty callback was removed from the success dialog | Produce a shareable community link or invitation token before restoring this action. |
| Admin dashboard / attention counts and rows | Counts always return zero; rows do not open queues | Return pending-post, report, and membership-request counts; add queue/detail/action endpoints and corresponding client pages. |
| Admin dashboard / Overview, Categories, Members, Moderation, Settings | Rows have no navigation | Return/manage category settings, membership roles/status, moderation actions, and community settings according to role. |

The static post text, prices, avatars/image placeholders, activity entries, profile name, and Town X Sports row are demo content. Do not treat them as server data.

## Suggested API contract

Use authenticated JSON requests under `/api/community/v1`, with stable IDs, ISO 8601 UTC timestamps, cursor pagination (`items`, `nextCursor`), and a consistent error object (`code`, `message`, optional field errors). Use `Authorization: Bearer <accessToken>`. Server responses should carry both display data and stable category/status identifiers; translated UI labels must not be used as identifiers.

| Priority | Proposed endpoint | Needed for |
| --- | --- | --- |
| P0 | `POST /api/auth/facebook` (existing client target), `POST /api/auth/refresh`, `POST /api/auth/logout`, `GET /api/community/v1/me` | Real session, startup validation, profile identity |
| P0 | `GET /towns`, `GET /me/communities`, `GET /communities/{id}`, `POST /communities` | Home/community pages and persistent creation |
| P0 | `GET /communities/{id}/categories`, `GET /posts?scope=following&categoryId=&q=&cursor=&sort=`, `GET /communities/{id}/posts`, `GET /categories/{id}/posts` | Real feed and category pages |
| P0 | `POST /communities/{id}/posts`, `GET /posts/{id}` | Publish and open a post |
| P1 | `GET /communities?q=&townId=&cursor=`, `POST /communities/{id}/membership`, `DELETE /communities/{id}/membership` | Explore, Join/Joined, discover search |
| P1 | `POST /media/uploads` (or presigned-upload flow) | Photo/video attachments |
| P1 | `PUT /posts/{id}/reaction`, `DELETE /posts/{id}/reaction`, `GET /posts/{id}/comments`, `POST /posts/{id}/comments` | Likes and comments |
| P1 | `PUT /me/saved-posts/{id}`, `DELETE /me/saved-posts/{id}`, `GET /me/saved-posts`, `GET /me/posts` | Profile collections |
| P1 | `GET /me/notifications`, `PATCH /me/notifications/{id}` | Activity and read state |
| P1 | `GET /communities/{id}/admin/summary`, queue list/detail/action routes for posts, reports, and membership requests | Admin attention flows |
| P2 | Community invitation, category management, member-role management, moderation history, and community settings routes | Share invitation and remaining admin rows |

Suggested request fields:

- `POST /api/auth/facebook`: the client already sends `accessToken`, `tokenType`, and `nonce`. Its response parser requires `accessToken`, `refreshToken`, `userId`, `userName`, and optional `isNewUser`. Keep secrets on the server.
- `POST /communities`: `name`, `description`, `townId`, `visibility`, `categoryNames` (or stable category template IDs), and `approvalRequired`. Return the created community with ID, owner role, category IDs, and member count.
- `POST /communities/{id}/posts`: `categoryId`, `text`, optional `mediaIds`; return the created post and its moderation status. If approval is required, only moderators and the author should see a pending post.
- Feed, post, and comment responses: include an author summary with `id`, `name`, and nullable `avatarUrl`. Refresh the stored Facebook name and profile image during login, and return that same author shape everywhere. Feed/post responses also include `id`, `communityId`, `categoryId`, text, price if marketplace posts support pricing, media, `createdAt`, `status`, reaction/comment counts, and whether the current user reacted or saved it.

## Rules and completion criteria

1. Authorize every read/write by membership and role. Public discovery may expose limited community data; private posts, admin queues, and user collections must be scoped to the signed-in user.
2. Validate text length, town/category IDs, media type and size, membership state, and approval rules on the server. Return field-level errors the editor can show without losing a draft.
3. Make repeated join, reaction, save, and moderation requests safe to retry. Counts and notification targets should be derived from server state.
4. Keep the HTTP repository aligned with the server contract and re-audit the remaining historical UI rows above. Remove hardcoded UI rows only as each endpoint is wired.
5. A flow is complete when its control produces a persistent result, survives app restart, updates relevant counts/lists, displays loading and failure states, and has an authorization/error-path test. A working endpoint alone does not make the UI action functional.
