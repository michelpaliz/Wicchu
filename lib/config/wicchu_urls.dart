abstract final class WicchuUrls {
  static const publicOrigin = String.fromEnvironment(
    'WICCHU_PUBLIC_ORIGIN',
    defaultValue: 'https://wicchu.com',
  );

  static String community(String id, [String slug = '']) =>
      slug.isEmpty ? '$publicOrigin/communities/$id' : '$publicOrigin/$slug';
  static String post(String id) => '$publicOrigin/posts/$id';
  static const privacy = '$publicOrigin/privacy';
  static const support = '$publicOrigin/support';
  static const dataDeletion = '$publicOrigin/data-deletion';
}
