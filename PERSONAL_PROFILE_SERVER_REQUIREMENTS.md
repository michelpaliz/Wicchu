# Personal profile layout: server requirements

The client now reads these optional fields from the existing
GET /api/community/v1/users/{userId} response (inside the existing user object):

- coverImageUrl: nullable HTTPS image URL
- bio: nullable string
- location: nullable display string
- followerCount: nullable nonnegative integer
- followingCount: nullable nonnegative integer

Missing counts remain hidden rather than appearing as zero. Personal profiles
display a single avatar; the optional cover field is parsed but not displayed.
Existing postCount/communityCount remain live.

## Pending server capabilities

Personal cover uploads and profile bio/location editing require a documented,
authenticated update endpoint and media-upload contract. The client does not yet
show an Edit cover button or send speculative update requests. Define validation,
image size limits, image removal, ownership checks, and returned profile fields.

Personal follow/unfollow and follower/following lists also need server support
before those counts can become navigation/actions. Counts must describe personal
relationships, not business followers or community memberships.

Saved posts use the existing authenticated listSavedPosts endpoint and are shown
only on the signed-in user's profile. They must never be included in public
profile responses.

Find friends currently searches members returned by existing joined-community
member endpoints. It does not access contacts or send friend requests. Those
endpoints must enforce membership, visibility, and blocking rules.
