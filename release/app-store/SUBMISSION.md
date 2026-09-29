# Wicchu App Store submission

Prepared 2026-09-29. Status: preparation in progress, NOT submitted for review.

## Release and access

- Uploaded: 1.0.0 (11), com.wicchu.wicchu, developer team P3F322KYHU.
- Uploaded build 11 contains placeholder iOS assets. Source assets are now replaced with existing Wicchu branding; a new build number is needed for the replacement upload.
- Price: free (confirmed by owner).
- Availability: Americas and Europe (confirmed by owner); confirm exact Apple storefront list before applying, including transcontinental countries/territories.
- Proposed primary category: Social Networking; secondary: Lifestyle. Owner confirmation pending.
- Support URL supplied: https://hexora.dev/wicchu/support — currently renders "Page unavailable".
- Working privacy policy: https://hexora.dev/wicchu/privacy — owner confirmation pending.
- Marketing URL candidate: https://hexora.dev/wicchu/.
- Xcode upload authorization works. App Store Connect metadata/submission API authorization has NOT been configured or verified. No connected browser automation is available in this session.

## Spanish listing draft (es-ES)

Name: Wicchu

Subtitle: Tu comunidad, más cerca

Promotional text:
Descubre comunidades y negocios locales, comparte novedades y organiza lo que ocurre cerca de ti en un mismo lugar.

Keywords:
comunidad,vecinos,barrio,negocios,noticias,eventos,grupos,local,empleos

Description:
Wicchu te conecta con las comunidades, los negocios y las personas de tu zona.

Descubre espacios locales
Explora comunidades y perfiles públicos, consulta su información y sigue los espacios que te interesan.

Encuentra lo que buscas
Organiza las publicaciones por categorías para seguir noticias, conversaciones y novedades de tu comunidad.

Participa y comparte
Publica texto, fotos y vídeos, comenta, reacciona y guarda publicaciones para volver a ellas más tarde. Las opciones de publicación dependen de tus permisos en cada espacio.

Gestiona tus espacios
Accede a tus comunidades y perfiles desde un mismo lugar. Los administradores disponen de herramientas para gestionar miembros, categorías, reglas y contenido.

Conoce tu entorno y mantente cerca de tu comunidad con Wicchu.

## English listing draft (en-US)

Name: Wicchu

Subtitle: Your local community, closer

Promotional text:
Discover local communities and businesses, share updates, and keep up with what is happening around you in one place.

Keywords:
community,neighbors,local,business,groups,news,events,neighborhood,jobs

Description:
Wicchu connects you with communities, businesses, and people in your area.

Discover local spaces
Explore communities and public profiles, learn about them, and follow the spaces that interest you.

Find relevant updates
Browse posts by category to follow local news, conversations, and community updates.

Take part and share
Share text, photos, and videos; comment, react, and save posts for later. Publishing options depend on your permissions in each space.

Manage your spaces
Access communities and public profiles in one place. Administrators can manage members, categories, rules, and content.

Get to know your surroundings and stay connected with Wicchu.

## Reviewer notes draft — complete and verify before use

Wicchu is a local community app with community feeds and public profiles.
Provide a dedicated, verified email/password demo account with access to populated review spaces. Do not use an owner's personal account. Keep its backend and content available during review.

Suggested review path:
1. Sign in with the supplied demo credentials.
2. Explore: open a community and inspect its feed and category filters.
3. Tap the community identity area to open information, rules, and members.
4. Open a joined community and use the composer to review rules and create a post.
5. Explore a business profile: followers cannot publish; owners/admins can.
6. You: inspect My spaces, saved posts, and settings.

Pending: tested login, contact first/last name, contact phone/email, deletion and blocking instructions. Never commit demo passwords or API private keys.

## Confirmed technical gaps and review risks

1. Account deletion: lib/features/settings/account_settings_page.dart opens WicchuUrls.dataDeletion. That default URL returns HTTP 403 in this environment. The working Hexora page instructs users to email support; no in-app account-deletion operation was found in AuthGateway. Implement deletion initiation and backend cleanup, including third-party token handling where applicable, before review.
2. Login: Facebook/Google/email are implemented; no Sign in with Apple or equivalent qualifying privacy-preserving provider was found. Assess Apple's 4.8 requirement and implement a qualifying alternative or document an applicable exception. Do not claim compliance based on ordinary email login alone.
3. User-generated content: post reporting and administrator moderation exist. Verify end-user blocking, objectionable-content filtering, response procedures, and public contact details. Administrator bans alone should not be assumed to satisfy all user-blocking needs.
4. Privacy: complete actual data-use declarations including all third-party SDK and backend practices. Do not select "Data Not Collected". See PRIVACY_REVIEW.md.
5. Push: build 11 distribution summary lacks aps-environment although source Runner.entitlements declares it. Verify final signed entitlement and Apple App ID Push Notifications capability before claiming notifications work on iOS.
6. Support page currently unavailable. A draft static page is provided alongside this document but has NOT been published.
7. Screenshots: not captured/uploaded. Capture real app screens from the final build with a dedicated populated demo account. The app targets iPhone AND iPad: provide both required size classes.
8. Age rating, content rights, export-compliance answers, EU trader details and Apple agreements require verified owner information. Do not guess.

## Screenshot plan

Use actual app captures, not generated mockups. Suggested screens: Explore, populated community feed, community information, business profile, My spaces.
- iPhone: 1320 × 2868 or another accepted 6.9-inch size.
- iPad: 2064 × 2752 or 2048 × 2732.
- PNG/JPEG without alpha, 1–10 per supported display class.
- No real private user information, loading spinners, debug banners, or invented product features.

## Checks completed

- Apple Distribution identity valid; build 11 upload succeeded.
- Reused assets/brand/wicchu-meta-icon-1024.png (opaque 1024 × 1024) for iOS icon and launch branding.
- xcrun actool compiled updated icon catalog for iPhone/iPad with deployment target 15.0.
- xcrun ibtool compiled updated LaunchScreen.storyboard.
- New assets have NOT yet been rebuilt into an IPA or uploaded.

## Sources

- https://developer.apple.com/app-store/review/guidelines/ (1.2, 4.8, 5.1.1)
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Final submission sequence

Resolve technical gaps → validate on device → capture screenshots → build with a new build number → export and verify entitlements → upload → wait for processing → complete listing/privacy/age rating/compliance/reviewer details → confirm availability and price → owner reviews concrete submission → submit.
