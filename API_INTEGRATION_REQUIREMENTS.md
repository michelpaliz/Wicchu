# Wicchu Frontend–Server Integration Requirements

This document is the contract required for the Wicchu Flutter application to persist and retrieve real data from the Hexora backend.

## 1. Production build requirements

The production application must use the default entry point:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Do not build production with `lib/main_preview.dart`. That entry point uses `DemoCommunityRepository`; its communities and posts exist only in device memory.

The production entry point is `lib/main.dart`, which injects `HttpCommunityRepository`.

The default server origin is:

```text
https://hexora.dev
```

If an explicit build value is supplied, it must be:

```bash
--dart-define=API_BASE_URL=https://hexora.dev
```

Do not include a trailing slash. Authentication and community API clients must use the same origin.

## 2. Authentication contract

### Facebook login

```http
POST /api/auth/facebook
Content-Type: application/json
```

```json
{
  "accessToken": "FACEBOOK_ACCESS_TOKEN",
  "tokenType": "classic",
  "nonce": "CLIENT_GENERATED_NONCE"
}
```

Successful responses must contain:

```json
{
  "accessToken": "WICCHU_ACCESS_TOKEN",
  "refreshToken": "WICCHU_REFRESH_TOKEN",
  "userId": "USER_ID",
  "userName": "USERNAME",
  "isNewUser": false
}
```

The frontend stores both Wicchu tokens in secure storage. It must never send the Facebook token to community endpoints.

During a successful Facebook login, the backend must read the user's public
profile name and profile picture, store or refresh the picture URL, and expose
it as `avatarUrl` from `/api/community/v1/me`. A missing Facebook picture is
represented as `null` so the client can display initials.

### Authenticated requests

Every `/api/community/v1` request requires:

```http
Accept: application/json
Authorization: Bearer WICCHU_ACCESS_TOKEN
```

JSON writes also require:

```http
Content-Type: application/json
```

### Token refresh

On HTTP `401`, call:

```http
POST /api/auth/refresh
Content-Type: application/json
```

```json
{ "refreshToken": "WICCHU_REFRESH_TOKEN" }
```

Save the returned `accessToken` and retry the original request once. If refresh fails, clear both tokens and require login again.

## 3. Community API calls

All paths below are relative to `https://hexora.dev` and require authentication unless explicitly marked public.

### Profile and activity

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/me` | Current Wicchu profile and counts |
| `GET` | `/api/community/v1/me/notifications` | Activity feed |
| `PATCH` | `/api/community/v1/me/notifications/read-all` | Mark all activity read |
| `PATCH` | `/api/community/v1/me/notifications/{notificationId}` | Mark one item read |
| `GET` | `/api/community/v1/me/posts` | Current user's posts |
| `GET` | `/api/community/v1/me/saved-posts` | Saved posts |
| `PUT` | `/api/community/v1/me/saved-posts/{postId}` | Save a post |
| `DELETE` | `/api/community/v1/me/saved-posts/{postId}` | Unsave a post |

### Location and towns

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/towns` | Supported Wicchu towns |
| `POST` | `/api/community/v1/towns/resolve` | Resolve GPS coordinates and return or create the town's stable ID |
| `GET` | `/api/community/v1/towns/reverse-geocode?latitude={lat}&longitude={lng}` | Resolve GPS position to the nearest supported town |
| `GET` | `/api/community/v1/communities/nearby?latitude={lat}&longitude={lng}&radiusKm=25` | Nearby communities |

Latitude and longitude must come from device location permission. Never log precise coordinates. Before community creation, send `{ "latitude": number, "longitude": number }` to `POST /api/community/v1/towns/resolve`. The server validates the location with Azure Maps, reuses an existing town or registers the detected town, and returns its stable `town._id`. Community creation must use that ID; a display name is not a valid `townId`.

### Community discovery and membership

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/communities` | Discover communities |
| `GET` | `/api/community/v1/communities?q={query}` | Search communities |
| `GET` | `/api/community/v1/communities?joined=true` | Joined communities |
| `GET` | `/api/community/v1/communities?managed=true` | Owned/administered communities |
| `GET` | `/api/community/v1/communities/{communityId}` | Community detail |
| `POST` | `/api/community/v1/communities/{communityId}/join` | Join or request membership |
| `DELETE` | `/api/community/v1/communities/{communityId}/membership` | Leave community |

### Create community

```http
POST /api/community/v1/communities
```

```json
{
  "name": "Echeandia",
  "description": "Local community",
  "townId": "MONGODB_TOWN_ID",
  "visibility": "public",
  "categoryNames": ["General", "News", "Events"],
  "approvalRequired": false
}
```

A successful response has HTTP `201` and a `community` object. The server creates the owner membership and categories in the same workflow. The frontend must not show success before this response is received.

### Update community

```http
PATCH /api/community/v1/communities/{communityId}
```

Supported fields are `name`, `description`, `visibility`, `approvalRequired`, and `imageBlobName`. Only owners/admins may update a community.

### Community rules update — backend support to confirm

The settings editor now sends an optional ordered `rules` array with the existing
community PATCH request:

```json
{ "rules": [{ "title": "Be respectful", "description": "Discuss ideas without personal attacks." }] }
```

The backend must authorize owners/admins, validate nonempty titles, persist the
array in order, and return it in the updated `community.rules` response and future
community reads. Omission preserves existing rules; an empty array removes all
rules. The previous documented update contract does not confirm this capability.
The frontend checks the returned rules and retains the draft with an error if
they differ, rather than reporting success. Other fields may already have saved
when this happens.

## 4. Categories and members

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/communities/{communityId}/categories` | List active categories |
| `POST` | `/api/community/v1/communities/{communityId}/categories` | Create category |
| `PATCH` | `/api/community/v1/communities/{communityId}/categories/{categoryId}` | Edit category |
| `DELETE` | `/api/community/v1/communities/{communityId}/categories/{categoryId}` | Disable category |
| `GET` | `/api/community/v1/communities/{communityId}/members` | List active members |
| `PATCH` | `/api/community/v1/communities/{communityId}/members/{userId}/role` | Assign `admin`, `moderator`, or `member` |

Category creation body:

```json
{ "name": "News", "description": "Local announcements" }
```

Role update body:

```json
{ "role": "moderator" }
```

## 5. Posts, reactions, comments, and sharing

### Feeds and post detail

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/posts` | Posts from joined communities |
| `GET` | `/api/community/v1/posts?q={query}` | Search joined feed |
| `GET` | `/api/community/v1/communities/{communityId}/posts` | Community posts |
| `GET` | `/api/community/v1/communities/{communityId}/posts?categoryId={id}&sort=latest` | Category feed |
| `GET` | `/api/community/v1/posts/{postId}` | Authenticated post detail |

### Create post

```http
POST /api/community/v1/communities/{communityId}/posts
```

```json
{
  "categoryId": "CATEGORY_ID",
  "text": "**Formatted** post text",
  "media": [
    {
      "type": "image",
      "blobName": "SERVER_RETURNED_BLOB_NAME",
      "url": "SERVER_RETURNED_URL"
    }
  ]
}
```

The user must have active membership. The category must belong to the community. The response status may be `published` or `pending_approval`; the frontend must preserve that distinction.

### Interactions

| Method | Path | Body/purpose |
|---|---|---|
| `PUT` | `/api/community/v1/posts/{postId}/reaction` | Add reaction |
| `DELETE` | `/api/community/v1/posts/{postId}/reaction` | Remove reaction |
| `GET` | `/api/community/v1/posts/{postId}/comments` | List comments |
| `POST` | `/api/community/v1/posts/{postId}/comments` | `{ "text": "Comment" }` |
| `POST` | `/api/community/v1/posts/{postId}/reports` | `{ "reason": "Reason" }` |
| `POST` | `/api/community/v1/posts/{postId}/share` | Record a share |

Every post and comment response must include the same compact author summary:

```json
{
  "author": {
    "id": "USER_ID",
    "name": "Display name",
    "avatarUrl": "https://..."
  }
}
```

`avatarUrl` may be `null`. The backend should refresh Facebook profile details
when the user signs in again instead of requiring each feed client to call the
Facebook Graph API.

## 6. Media upload

```http
POST /api/community/v1/media/uploads
Authorization: Bearer WICCHU_ACCESS_TOKEN
Content-Type: multipart/form-data
```

The multipart field name must be `media`.

Supported formats:

- Images: JPEG, PNG, WebP
- Videos: MP4, MOV
- Maximum request file size: 25 MB
- Post attachments: maximum 10
- Community photo client limit: 10 MB

The server validates the file's actual signature, not only its declared MIME type. Persist the returned `blobName`; direct Azure URLs may be private or temporary.

## 7. Administration and moderation

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/communities/{communityId}/admin/summary` | Attention counts |
| `GET` | `/api/community/v1/communities/{communityId}/admin/pending-posts` | Pending posts |
| `PATCH` | `/api/community/v1/communities/{communityId}/admin/pending-posts/{postId}` | `{ "decision": "approve" }` or `reject` |
| `GET` | `/api/community/v1/communities/{communityId}/admin/reports` | Reports |
| `PATCH` | `/api/community/v1/communities/{communityId}/admin/reports/{reportId}` | `{ "decision": "resolve" }` or `dismiss` |
| `GET` | `/api/community/v1/communities/{communityId}/admin/membership-requests` | Pending members |
| `PATCH` | `/api/community/v1/communities/{communityId}/admin/membership-requests/{userId}` | `{ "decision": "approve" }` or `reject` |

The frontend must display authorization errors and must never assume client-side role checks replace server authorization.

## 8. Free local promotion pilot

The promotion pilot provides one free 30-day trial per account. The trial begins with the first submitted campaign, is limited to one town, permits one pending or active campaign at a time, and never converts into a paid plan automatically. Each campaign may run for up to seven days and requires community moderator approval.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/community/v1/promotions/eligibility` | Trial dates, eligibility, town, and current campaign |
| `POST` | `/api/community/v1/promotions` | Submit an owned published post with `{ "postId": "...", "durationDays": 7 }` |
| `GET` | `/api/community/v1/promotions/mine` | Campaign history and performance counts |
| `GET` | `/api/community/v1/promotions/{promotionId}` | Campaign detail |
| `PATCH` | `/api/community/v1/promotions/{promotionId}/cancel` | Cancel a pending or active campaign |
| `POST` | `/api/community/v1/promotions/{promotionId}/impression` | Record one unique daily impression per member |
| `POST` | `/api/community/v1/promotions/{promotionId}/click` | Record one unique daily post open per member |
| `GET` | `/api/community/v1/communities/{communityId}/admin/promotions` | List promotions awaiting review |
| `PATCH` | `/api/community/v1/communities/{communityId}/admin/promotions/{promotionId}` | Submit `approve` or `reject` in `decision` |

An active promoted post can appear in normal feed responses with:

```json
{
  "promotion": {
    "id": "PROMOTION_ID",
    "sponsored": true,
    "startsAt": "2026-09-22T12:00:00.000Z",
    "endsAt": "2026-09-29T12:00:00.000Z"
  }
}
```

The frontend must display a visible `Sponsored` label and record an impression only after the promoted item is rendered. It should record a click when the member opens the promoted post. Neither tracking call may be sent for the advertiser's own campaign.

## 9. Public sharing and deep links

These endpoints do not expose content from private communities:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/wicchu/posts/{postId}` | Public HTML and Open Graph preview |
| `GET` | `/wicchu/api/posts/{postId}` | Public published-post preview data |

Only `published` posts from `public`, active communities may be returned. Private, pending, removed, and missing posts must all behave as unavailable.

Shared URLs use:

```text
https://hexora.dev/wicchu/posts/{postId}
```

The landing page opens the app with:

```text
wicchu://posts/{postId}
```

Android and iOS manifests must retain the `wicchu` URL scheme. After login, the app opens the shared preview. Visitors must join before reactions, comments, saving, or reporting are enabled.

## 10. Required response behavior

- IDs are stable strings.
- Times are ISO 8601 UTC timestamps.
- Success responses are JSON objects, not HTML.
- Validation failures use HTTP `400`.
- Missing resources use `404`.
- Authentication failures use `401`.
- Permission failures use `403`.
- Conflicts use `409`.
- Error responses should contain a human-readable `message`.
- The client must show errors and must not convert failed writes into local success.

## 11. Device requirements

- Internet permission is required.
- Location permission is required when creating a community or requesting nearby discovery.
- Facebook Android key hashes must match the certificate that signed the installed APK.
- Secure storage must be available for Wicchu access and refresh tokens.
- The APK must be rebuilt after dependency or Android-manifest changes.

## 12. Production verification checklist

1. Build from `lib/main.dart` with no preview target.
2. Confirm `API_BASE_URL` is `https://hexora.dev`.
3. Uninstall old preview/debug APKs before installing the production build.
4. Log in and confirm `GET /api/community/v1/me` succeeds.
5. Grant location permission and confirm reverse geocoding returns a real `town._id`.
6. Create a community and require HTTP `201` before showing success.
7. Refresh the app and verify the community still appears.
8. Create a post and require a server response before showing the publish dialog.
9. Refresh from another device and verify the post persists.
10. Share the post URL and verify its public preview.

If a community or post disappears after restart and no corresponding server request exists, the app was built with the preview entry point or another API origin.
