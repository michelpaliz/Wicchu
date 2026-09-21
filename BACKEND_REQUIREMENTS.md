# Wicchu backend handoff: unfinished UI flows

This document inventories controls visible in the Flutter app that do not yet complete a real server-backed action. It is based on the client code in this repository. The server lives elsewhere, so the endpoints below are **proposals**, except for the Facebook endpoint that the client already calls. Confirm the contract against the Hexora server before implementation.

## Current integration

- `lib/main.dart` always injects `DemoCommunityRepository`. Towns, communities, categories, and admin counts come from local demo data; a created community disappears when the app restarts.
- `FacebookAuthGateway` calls `POST /api/auth/facebook` at `API_BASE_URL` (default `https://hexora.dev`). The backend implementation is not in this repository. Android Facebook configuration is currently incomplete in the local preview. `hasSession()` only checks whether a refresh token exists; it does not refresh or validate the session.
- The README identifies `/api/community/v1` as the community API prefix. All community endpoints below use that prefix.
- Language and Light/Dark/System appearance choices already work locally and persist in device preferences. They do not need backend endpoints.
- The Home category chips and search field respond to taps, but they only filter two hardcoded demo posts.

## UI gap inventory

| Screen / control | What happens now | Backend capability and Flutter wiring needed |
| --- | --- | --- |
| Login / Continue with Facebook | Client attempts the Facebook SDK exchange and calls `/api/auth/facebook`; no configured end-to-end sign-in in this repository | Verify token with Meta, return the session shape below, and add refresh/revocation endpoints. Client must refresh on startup and handle expired/revoked sessions. |
| Home / community card | Opens a page backed by `DemoCommunityRepository` | Fetch the signed-in user's joined communities and each community's detail/member count. Replace demo repository with an HTTP implementation. |
| Home / neighborhood feed, search, category chips | Two hardcoded posts are shown; filtering is local | List real posts from joined communities with category/search filters, pagination, counts, author, media, and community data. Client must render the response and handle loading/empty/error states. |
| Home / New post | Opens the editor | The editor needs post creation; see Publish below. |
| Explore / search icon | Empty callback | Search/discover public communities by name and town, with pagination. Wire search UI to results. |
| Explore / community cards and Joined | Demo rows; Joined callback is empty | Fetch discover results and the user's membership status. Open community detail; support join/leave or membership request depending on visibility. |
| Explore / Town X Sports Join | Hardcoded row with disabled button | Replace with real discover result and enabled join/request action. |
| Explore / popular topics chips | Static labels | Either return popular categories/communities with counts and open filtered results, or make these noninteractive display elements. |
| Activity | Four hardcoded notifications | Fetch user notifications, unread count, mark read, and open the target post/community/request. |
| You / name, handle, counts | Hardcoded Michael profile and counts | Fetch current user profile and counts for communities and posts. |
| You / My communities, My posts, Saved posts, Communities I manage | Rows have no navigation | Fetch each collection and add list pages. Saving a post needs add/remove/list APIs. |
| You / Settings, Help | Rows have no navigation | Define the intended client pages. Language and appearance are already local; account preferences need an API only if they must sync across devices. Help content may be static. |
| Community / Joined, Share, more menu | Empty callbacks | Membership action/status, a shareable deep link or invite, and defined menu actions. Native share UI is a client task; backend is needed for invitation tokens if invitations are required. |
| Community / categories and latest posts | Categories come from demo data; latest post is hardcoded | Fetch category list and real community posts, including the category's rules and approval policy. |
| Category / Latest and Popular | Selection callback is empty | List posts by category with `sort=latest` or `sort=popular`; wire selected state and pagination. |
| Post card / tap, like count, comments, share icon | Card tap is null in current uses; counts and icons are display only | Provide post detail, reactions, comments, and canonical post link. Client must turn icons into actions and update counts optimistically or from server responses. |
| Create post / Photo and Video | Empty callbacks | Media upload workflow with type/size validation and URLs/IDs returned for post creation. Client must launch the picker, show upload progress, and allow removal before publish. |
| Create post / Publish | Pops the editor without saving text, category, or media | Create a post, validate input, return status `published` or `pendingApproval`, and show success/error in the client. |
| Create community / Create | Saves only to an in-memory list | Persist community, selected town, visibility, description, and categories. Assign creator as owner. Refresh lists after creation. |
| Create community / Approve posts before publishing | Switch changes local state, but its value is not included in `CreateCommunityInput` | Add an approval-policy field to the client model and create request; enforce it when publishing posts. |
| Create community / Share invitation | Empty callback in success dialog | Produce shareable community link; if joining by invitation, create/redeem invitation tokens. |
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
- Feed/post responses: `id`, `communityId`, `categoryId`, author summary, text, price if marketplace posts support pricing, media, `createdAt`, `status`, reaction/comment counts, and whether the current user reacted or saved it. The current `CommunityPost` model has no price/count fields, so the client model must grow with the API.

## Rules and completion criteria

1. Authorize every read/write by membership and role. Public discovery may expose limited community data; private posts, admin queues, and user collections must be scoped to the signed-in user.
2. Validate text length, town/category IDs, media type and size, membership state, and approval rules on the server. Return field-level errors the editor can show without losing a draft.
3. Make repeated join, reaction, save, and moderation requests safe to retry. Counts and notification targets should be derived from server state.
4. Replace `DemoCommunityRepository` in `main.dart` with an HTTP repository and expand `CommunityRepository` for posts, membership, notifications, profile, and admin actions. Remove hardcoded UI rows only as each endpoint is wired.
5. A flow is complete when its control produces a persistent result, survives app restart, updates relevant counts/lists, displays loading and failure states, and has an authorization/error-path test. A working endpoint alone does not make the UI action functional.
