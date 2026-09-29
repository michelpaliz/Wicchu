# Privacy declaration worksheet — not approved answers

The app and backend must both be reviewed. The public policy mentions automated moderation by OpenAI; confirm the deployed implementation and disclosure/consent flow. The frontend alone cannot establish retention, tracking, cross-service use, or all SDK collection.

| Potential data type | Evidence / feature | What needs confirmation |
| --- | --- | --- |
| Name, email, user ID, profile image | Email/Google/Facebook login and profiles | Linked to identity, purpose and retention |
| Photos/videos, posts, comments | Community uploads and interactions | Moderation vendors, public visibility, deletion |
| Location | Geolocator, nearby discovery and business locations | Precise/coarse data sent to server, storage and optional use |
| Interactions | Reactions, saved posts, memberships, reports | Analytics versus app functionality, retention |
| Push/device identifiers | Firebase Messaging | Token storage, account linkage and retention |
| Diagnostics and usage | Third-party SDKs and server logs | Exact collection, vendors and retention |
| Tracking / advertising | Facebook SDK, Google auth, local promotion features | Actual SDK configuration and cross-company tracking; do not infer solely from dependency presence |

Required owner/backend answers:
- Is data used for advertising, cross-app tracking, or sold/shared beyond service provision?
- Which vendors process user content and location, and under what retention terms?
- What deletion, backup and moderation retention rules are deployed?
- Does the app request any required consent before sending personal data to third-party AI services?
- Confirm age-rating questionnaire answers based on actual content, moderation, messaging and access controls.

Privacy URL candidate: https://hexora.dev/wicchu/privacy (loaded successfully).
Support URL: https://hexora.dev/wicchu/support (currently unavailable).
