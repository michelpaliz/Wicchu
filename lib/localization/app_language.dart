import 'package:flutter/material.dart';

class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    super.key,
    required this.languageCode,
    required this.onLanguageChanged,
    required super.child,
  });

  final String languageCode;
  final ValueChanged<String> onLanguageChanged;

  static AppLanguageScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      languageCode != oldWidget.languageCode;
}

extension AppTranslation on BuildContext {
  bool get isSpanish => Localizations.localeOf(this).languageCode == 'es';

  String tr(String english, [Map<String, String> values = const {}]) {
    var result = isSpanish ? (_spanish[english] ?? english) : english;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  String trNotification(String english) {
    if (!isSpanish) return english;
    final exact = _spanish[english];
    if (exact != null) return exact;
    const invitationPrefix = 'invited you to join ';
    if (english.startsWith(invitationPrefix)) {
      return 'te invitó a unirte a ${english.substring(invitationPrefix.length)}';
    }
    final roleChange = RegExp(
      r'^changed your role to (.+) in (.+)$',
    ).firstMatch(english);
    if (roleChange != null) {
      final role = switch (roleChange.group(1)) {
        'an administrator' => 'administrador',
        'a moderator' => 'moderador',
        'a member' => 'miembro',
        final value => value ?? '',
      };
      return 'cambió tu rol a $role en ${roleChange.group(2)}';
    }
    return english;
  }

  String trError(Object error) {
    final message = error.toString();
    if (!isSpanish) return message;
    final normalized = message.replaceFirst(RegExp(r'^Exception: '), '');
    return _spanish[normalized] ??
        tr('Something went wrong. Please try again.');
  }

  String trCount(
    int count, {
    required String singular,
    required String plural,
  }) => tr(count == 1 ? singular : plural, {'count': '$count'});
}

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context);
    return PopupMenuButton<String>(
      tooltip: context.tr('Language'),
      onSelected: language.onLanguageChanged,
      itemBuilder: (context) => [
        for (final (code, name) in const [('en', 'English'), ('es', 'Español')])
          PopupMenuItem(
            value: code,
            child: Row(
              children: [
                Expanded(child: Text(name)),
                if (language.languageCode == code)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded),
            const SizedBox(width: 4),
            Text(language.languageCode.toUpperCase()),
          ],
        ),
      ),
    );
  }
}

const _spanish = <String, String>{
  'Your profile, your community': 'Tu perfil, tu comunidad',
  'This information will be visible to other Wicchu users.':
      'Esta información será visible para otros usuarios de Wicchu.',
  'Tell us a little about yourself.': 'Cuéntanos un poco sobre ti.',
  'Tell us about yourself, your interests or what makes you unique…':
      'Cuéntanos algo sobre ti, tus intereses o lo que te hace especial…',
  'Add your location': 'Añade tu ubicación',

  'Personal information': 'Información personal',
  'Bio': 'Biografía',
  'Profile saved': 'Perfil guardado',
  'This field is required.': 'Este campo es obligatorio.',
  'Use letters, numbers, dots, underscores or hyphens.':
      'Usa letras, números, puntos, guiones bajos o guiones.',

  'Tell us what is wrong. Reports are confidential.':
      'Cuéntanos qué ocurre. Las denuncias son confidenciales.',
  'Report to': 'Enviar denuncia a',
  'Reports are routed to community moderators or Wicchu Safety as appropriate.':
      'Las denuncias se envían a los moderadores de la comunidad o al equipo de seguridad de Wicchu según corresponda.',
  'Additional details (optional)': 'Detalles adicionales (opcional)',
  'Submit report': 'Enviar denuncia',
  'Wicchu Safety': 'Seguridad de Wicchu',
  'Contact Wicchu Safety': 'Contactar a Seguridad de Wicchu',
  'Safety request': 'Solicitud de seguridad',
  'Safety issue': 'Problema de seguridad',
  'Resolve request': 'Resolver solicitud',
  'Send to Wicchu Safety': 'Enviar a Seguridad de Wicchu',
  'Request sent to Wicchu Safety': 'Solicitud enviada a Seguridad de Wicchu',
  'Account or space may be compromised':
      'La cuenta o el espacio pueden estar comprometidos',
  'Another administrator is abusing their role':
      'Otro administrador está abusando de su función',
  'Ownership dispute': 'Disputa de propiedad',
  'Impersonation': 'Suplantación de identidad',
  'Illegal or dangerous activity': 'Actividad ilegal o peligrosa',
  'Content cannot be removed': 'No se puede eliminar el contenido',
  'Appeal a platform restriction': 'Apelar una restricción de la plataforma',
  'Other safety concern': 'Otro problema de seguridad',
  'Explain what happened and what help you need':
      'Explica qué ocurrió y qué ayuda necesitas',
  'Platform moderation': 'Moderación de la plataforma',
  'Resolved': 'Resueltos',
  'No pending platform reports.': 'No hay reportes de plataforma pendientes.',
  'No resolved platform reports.': 'No hay reportes de plataforma resueltos.',
  'Community admin': 'Administrador de comunidad',
  'Reporter': 'Reportado por',
  'Submitted': 'Enviado',
  'Evidence snapshot': 'Evidencia guardada',
  'Resolution': 'Resolución',
  'Note': 'Nota',
  'Dismiss report': 'Descartar reporte',
  'Dismiss request': 'Descartar solicitud',
  'Warn admin': 'Advertir al administrador',
  'Remove admin role': 'Quitar rol de administrador',
  'Suspend user': 'Suspender usuario',
  'Suspend community': 'Suspender comunidad',
  'Ban appeal': 'Apelación de expulsión',
  'Restore membership': 'Restaurar membresía',
  'Reason shown to member': 'Motivo mostrado al miembro',
  'The member will receive this reason.': 'El miembro recibirá este motivo.',
  'Internal moderator note (optional)': 'Nota interna del moderador (opcional)',
  'Internal moderator note': 'Nota interna del moderador',
  'Only community and Wicchu moderators can see this.':
      'Solo los moderadores de la comunidad y de Wicchu pueden verla.',
  'Ban duration': 'Duración de la expulsión',
  'Transfer ownership': 'Transferir propiedad',
  'Send transfer': 'Enviar transferencia',
  'Ownership transfer': 'Transferencia de propiedad',
  'Ownership transfer sent. The administrator must accept it.':
      'Transferencia enviada. El administrador debe aceptarla.',
  'The owner invited you to take ownership of this space.':
      'El propietario te invitó a asumir la propiedad de este espacio.',
  '{name} must accept the transfer. After acceptance, they will become the owner and you will become an administrator.':
      '{name} debe aceptar la transferencia. Después, será propietario y tú pasarás a ser administrador.',
  'Step down as administrator': 'Dejar el cargo de administrador',
  'Step down as administrator?': '¿Dejar el cargo de administrador?',
  'Step down': 'Dejar el cargo',
  'You will become a regular member and lose access to management tools.':
      'Pasarás a ser miembro y perderás acceso a las herramientas de administración.',
  'You are now a regular member.': 'Ahora eres un miembro regular.',
  'Permanent': 'Permanente',
  '1 day': '1 día',
  '7 days': '7 días',
  '30 days': '30 días',
  'Your community access is restricted':
      'Tu acceso a la comunidad está restringido',
  'This restriction is permanent unless it is reviewed.':
      'Esta restricción es permanente a menos que se revise.',
  'Access returns on': 'El acceso se restablece el',
  'Community rules violation.': 'Incumplimiento de las reglas de la comunidad.',
  'Request Wicchu Safety review': 'Solicitar revisión de Seguridad de Wicchu',
  'Why should this ban be reviewed?':
      '¿Por qué debería revisarse esta expulsión?',
  'Submit appeal': 'Enviar apelación',
  'Your appeal was sent to Wicchu Safety.':
      'Tu apelación fue enviada a Seguridad de Wicchu.',
  'Community posts are unavailable while your access is restricted.':
      'Las publicaciones no están disponibles mientras tu acceso esté restringido.',
  'Internal note or warning message': 'Nota interna o mensaje de advertencia',
  'Confirm': 'Confirmar',
  'Report page': 'Reportar página',
  'Report community': 'Reportar comunidad',
  'Report sent to Wicchu Safety': 'Reporte enviado a Seguridad de Wicchu',
  'Hide post': 'Ocultar publicación',
  'Report comment': 'Reportar comentario',
  'Report profile': 'Reportar perfil',
  'Spam': 'Spam',
  'Harassment': 'Acoso',
  'Hate speech': 'Discurso de odio',
  'Violence': 'Violencia',
  'Sexual content': 'Contenido sexual',
  'Self-harm': 'Autolesión',
  'Scam or fraud': 'Estafa o fraude',
  'Illegal activity': 'Actividad ilegal',
  'Comment {id}': 'Comentario {id}',
  'Member {id}': 'Miembro {id}',
  'Remove comment': 'Eliminar comentario',
  'Restrict member': 'Restringir miembro',
  'Write something…': 'Escribe algo…',
  'Before posting, read and agree to the community rules.':
      'Antes de publicar, lee y acepta las reglas de la comunidad.',
  'Agree and continue': 'Aceptar y continuar',

  'Unable to load rating': 'No se pudo cargar la valoración',
  'Read the guidelines for a safe and respectful community.':
      'Lee las normas para mantener un espacio seguro y respetuoso.',
  'Website, directions and more': 'Sitio web, cómo llegar y más',

  'Unable to load members': 'No se pudieron cargar los miembros',
  'Help our community grow': 'Ayúdanos a hacer crecer la comunidad',
  'Invite people from {town}': 'Invita a más personas de {town}.',
  'Administration': 'Administración',
  'No members found': 'No se encontraron miembros',

  'Leave community': 'Salir de la comunidad',
  'You own this community': 'Eres propietario de esta comunidad',
  'You administer this community': 'Eres administrador de esta comunidad',
  'You moderate this community': 'Eres moderador de esta comunidad',
  'You are a member of this community': 'Eres miembro de esta comunidad',
  'Leave this community?': '¿Salir de esta comunidad?',

  'Community type': 'Tipo de comunidad',
  'Creation date': 'Fecha de creación',
  'Public': 'Pública',
  'Private': 'Privada',

  'Public profile': 'Perfil público',
  'Discover communities, businesses and public profiles near you.':
      'Descubre comunidades, negocios y perfiles públicos cerca de ti.',
  'Not finding what you need?': '¿No encuentras lo que buscas?',
  'Explore more profiles, businesses and communities.':
      'Explora más perfiles, negocios y comunidades.',

  'Edit cover': 'Editar portada',
  'Manage profile': 'Administrar perfil',
  'Share your first post': 'Comparte tu primera publicación',
  'Keep your followers updated with news, photos and announcements.':
      'Mantén a tus seguidores al día con noticias, fotos y anuncios.',
  'Updates from this profile will appear here.':
      'Las novedades de este perfil aparecerán aquí.',

  'Your changes were saved, but the profile category could not be saved. Please try again later.':
      'Se guardaron los cambios, pero no el tipo de perfil. Inténtalo de nuevo más tarde.',
  'Your profile was created, but its category could not be saved. You can set it later in settings.':
      'Se creó tu perfil, pero no se guardó su tipo. Puedes configurarlo más tarde en ajustes.',

  'Local business': 'Negocio local',
  'Local businesses': 'Negocios locales',
  'Person': 'Persona',
  'Creator': 'Creador',
  'Organization': 'Organización',
  'Profile category': 'Tipo de perfil',
  'Business services': 'Servicios del negocio',
  'Choose up to 10 services shown on your page.':
      'Elige hasta 10 servicios para mostrar en tu página.',
  'Choose no more than 10 business services.':
      'Elige un máximo de 10 servicios del negocio.',
  'Services': 'Servicios',
  'Gardening': 'Jardines',
  'Pools': 'Piscinas',
  'Concierge': 'Conserjería',
  'Cleaning': 'Limpieza',
  'Maintenance': 'Mantenimiento',
  'Construction': 'Construcción',
  'Food': 'Alimentación',
  'Retail': 'Comercio',
  'Real estate': 'Bienes raíces',
  'Health': 'Salud',
  'Beauty': 'Belleza',
  'Transport': 'Transporte',
  'Education': 'Educación',
  'Professional services': 'Servicios profesionales',
  'Choose a profile category.': 'Elige un tipo de perfil.',

  'Language': 'Idioma',
  'Appearance': 'Apariencia',
  'System': 'Sistema',
  'Light': 'Claro',
  'Dark': 'Oscuro',
  'Home': 'Inicio',
  'Grid': 'Cuadrícula',
  'Allow photo access for Wicchu in iPhone Settings, then try again.':
      'Permite el acceso a las fotos para Wicchu en Ajustes del iPhone y vuelve a intentarlo.',
  'Saved': 'Guardados',
  'Find people from your communities here.':
      'Aquí encontrarás personas de tus comunidades.',
  'Find people on Wicchu here.': 'Aquí encontrarás personas en Wicchu.',
  'Search people': 'Buscar personas',
  'Find people': 'Encontrar personas',
  'No people found.': 'No se encontraron personas.',
  'Try another name or username.':
      'Prueba con otro nombre o nombre de usuario.',
  '{count} shared community': '{count} comunidad en común',
  '{count} shared communities': '{count} comunidades en común',
  'Find friends': 'Encontrar amigos',
  'Personal profile': 'Perfil personal',
  'Account menu': 'Menú de cuenta',
  'Switch profile': 'Cambiar perfil',
  'Posting as {name}': 'Publicando como {name}',
  'For you': 'Para ti',
  'Explore': 'Explorar',
  'Activity': 'Actividad',
  'Communities': 'Comunidades',
  'You': 'Tú',
  'Close search': 'Cerrar búsqueda',
  'Search posts': 'Buscar publicaciones',
  'Search posts in {community}': 'Buscar publicaciones en {community}',
  'No posts found in {community}':
      'No se encontraron publicaciones en {community}',
  'Search communities': 'Buscar comunidades',
  'Retry': 'Reintentar',
  'New post': 'Nueva publicación',
  'Your town': 'Tu ciudad',
  'Choose a town': 'Elige una ciudad',
  'Page location': 'Ubicación de la página',
  'Community location': 'Ubicación de la comunidad',
  'Use my current town': 'Usar mi localidad actual',
  'This location is used for discovery and local weather.':
      'Esta ubicación se usa para descubrir espacios y mostrar el clima local.',
  'YOUR NEIGHBORHOOD': 'TU VECINDARIO',
  'Good things happen nearby.': 'Lo bueno pasa cerca de ti.',
  'The latest from {town} and your communities.':
      'Lo último de {town} y tus comunidades.',
  'The latest from your communities.': 'Lo último de tus comunidades.',
  'Choose a community': 'Elige una comunidad',
  'More categories': 'Más categorías',
  'Explore communities': 'Explorar comunidades',
  'Nearby communities': 'Comunidades cercanas',
  'Finding nearby communities…': 'Buscando comunidades cercanas…',
  'Using your location': 'Usando tu ubicación',
  'Show all': 'Mostrar todas',
  'Optional': 'Opcional',
  'Discard community draft?': '¿Descartar el borrador de la comunidad?',
  'Your changes will not be saved.': 'Tus cambios no se guardarán.',
  'Creating…': 'Creando…',
  'Rules and review': 'Normas y revisión',
  'Choose the topics for your community. You can change them later.':
      'Elige los temas de tu comunidad. Puedes cambiarlos más adelante.',
  'Rules are optional. You can add or edit them later.':
      'Las normas son opcionales. Puedes añadirlas o editarlas más adelante.',
  'Review your community': 'Revisa tu comunidad',
  'Use your location to find nearby communities.':
      'Usa tu ubicación para encontrar comunidades cercanas.',
  'Be the first to create a community and connect with people in your area.':
      'Sé el primero en crear una comunidad y empieza a conectar con personas de tu zona.',
  'Discover communities nearby and connect with your neighbors.':
      'Descubre comunidades cercanas y conecta con tus vecinos.',
  'Try another name or location.': 'Prueba con otro nombre o ubicación.',
  'No communities nearby yet': 'Aún no hay comunidades cerca de ti',
  'No communities to explore yet': 'Aún no hay comunidades para explorar',
  'Discover and join communities in your area.':
      'Descubre y únete a comunidades de tu zona.',
  'All communities': 'Todas',
  'View community image': 'Ver imagen de la comunidad',
  'Open settings': 'Abrir ajustes',
  'Could not get your location. Try again.':
      'No se pudo obtener tu ubicación. Inténtalo de nuevo.',
  'Your communities': 'Tus comunidades',
  'Join a community to see local updates here.':
      'Únete a una comunidad para ver novedades locales aquí.',
  'Join a community before creating a post.':
      'Únete a una comunidad antes de crear una publicación.',
  '{count} neighbors': '{count} vecinos',
  '{count} neighbor': '{count} vecino',
  'Neighborhood feed': 'Noticias de tu barrio',
  'Updates and finds from around you': 'Novedades y hallazgos cerca de ti',
  'Search local posts': 'Buscar publicaciones locales',
  'All': 'Todos',
  'News': 'Noticias',
  'Marketplace': 'Mercado',
  'Jobs': 'Empleos',
  'Events': 'Eventos',
  'Housing': 'Vivienda',
  'General': 'General',
  'Politics': 'Política',
  'Local Businesses': 'Negocios locales',
  'Sports': 'Deportes',
  'Lost & Found': 'Objetos perdidos',
  'Category': 'Categoría',
  'No posts in {category} yet': 'Aún no hay publicaciones en {category}',
  'Be the first to share something in this category.':
      'Sé el primero en publicar algo en esta categoría.',
  'Post in {category}': 'Publicar en {category}',
  'No posts found': 'No se encontraron publicaciones',
  'Post unavailable': 'Publicación no disponible',
  'No categories found': 'No se encontraron categorías',
  'No communities found': 'No se encontraron comunidades',
  'No activity yet': 'Todavía no hay actividad',
  'Mark all read': 'Marcar todas como leídas',
  'Additional information': 'Información adicional',
  'Posts and content': 'Publicaciones y contenido',
  'Remove cover photo': 'Eliminar foto de portada',
  'Shown as a {network} link.': 'Se mostrará como un enlace de {network}.',
  'Clear link': 'Borrar enlace',
  'Enter the full URL of your link.': 'Introduce la URL completa de tu enlace.',
  'Name shown on the profile (e.g. Telegram, Website, Facebook).':
      'Nombre que se mostrará (ej. Telegram, Web, Facebook).',
  'Official links appear in the profile so people can find you easily.':
      'Los enlaces oficiales aparecerán en el perfil para que puedan encontrarte fácilmente.',
  'Add links to your social networks, website or other official channels.':
      'Añade enlaces a tus redes sociales, página web u otros canales oficiales.',
  'Map': 'Mapa',
  'Open link': 'Abrir enlace',
  'Websites, social networks, maps and other useful links.':
      'Sitios web, redes sociales, mapas y otros enlaces útiles.',
  'Find important links for this community or profile here.':
      'Aquí puedes encontrar enlaces importantes de esta comunidad o perfil.',
  'Keep sharing useful local content and invite members to take part.':
      'Sigue compartiendo contenido local útil e invita a los miembros a participar.',
  'New members': 'Nuevos miembros',
  'Activity in the last 30 days': 'Actividad en los últimos 30 días',
  'More history is needed to show member growth.':
      'Se necesita más historial para mostrar el crecimiento de miembros.',
  'Posts in the last 30 days': 'Publicaciones en los últimos 30 días',
  'Community statistics are not available yet.':
      'Las estadísticas de la comunidad aún no están disponibles.',
  'A summary of your community’s activity and growth.':
      'Resumen de la actividad y crecimiento de tu comunidad.',
  'Notification settings': 'Ajustes de notificaciones',
  'Log out': 'Cerrar sesión',
  'Signing out…': 'Cerrando sesión…',
  '{communities} Communities · {posts} Posts':
      '{communities} comunidades · {posts} publicaciones',
  '{count} community': '{count} comunidad',
  '{count} communities': '{count} comunidades',
  '{count} post': '{count} publicación',
  '{count} posts': '{count} publicaciones',
  'Owner': 'Propietario',
  'Save post': 'Guardar publicación',
  'Unsave post': 'Quitar de guardados',
  'Edit': 'Editar',
  'Edit community': 'Editar comunidad',
  'Edit business': 'Editar negocio',
  'About {name}': 'Acerca de {name}',
  'Community rating': 'Valoración de la comunidad',
  'Useful links': 'Enlaces útiles',
  'Directions': 'Cómo llegar',
  'Helps nearby people find your profile.':
      'Ayuda a las personas cercanas a encontrar tu perfil.',
  'Business location': 'Ubicación del negocio',
  'Business address': 'Dirección del negocio',
  'Street, town, province': 'Calle, localidad, provincia',
  'Map pin saved': 'Ubicación guardada en el mapa',
  'Show exact location publicly': 'Mostrar la ubicación exacta públicamente',
  'When disabled, visitors only see the profile town.':
      'Si se desactiva, los visitantes solo verán la localidad del perfil.',
  'Unable to open link. Please try again.':
      'No se pudo abrir el enlace. Inténtalo de nuevo.',
  'Enter a rule title.': 'Introduce un título para la regla.',
  'Describe this rule.': 'Describe esta regla.',
  'Share profile': 'Compartir perfil',
  'Social links': 'Redes y contacto',
  'Save changes': 'Guardar cambios',
  'Hide {count} reply': 'Ocultar {count} respuesta',
  'Hide {count} replies': 'Ocultar {count} respuestas',
  'Hide replies': 'Ocultar respuestas',
  'View {count} reply': 'Ver {count} respuesta',
  'View {count} replies': 'Ver {count} respuestas',
  'Welcome back': 'Te damos la bienvenida',
  'Join your neighborhood': 'Conecta con tu comunidad',
  'Recover access to your account': 'Recupera el acceso a tu cuenta',
  'Enter your email and we will send you a reset link.':
      'Introduce tu correo y te enviaremos un enlace para restablecer la contraseña.',
  'Connect with your neighbors and discover what is happening nearby.':
      'Conecta con tus vecinos y descubre qué pasa cerca de ti.',
  'Show password': 'Mostrar contraseña',
  'Hide password': 'Ocultar contraseña',
  'Enter your password.': 'Introduce tu contraseña.',
  'More options': 'Más opciones',
  'Like': 'Me gusta',
  'Unlike': 'Ya no me gusta',
  'Report post': 'Denunciar publicación',
  'Report category': 'Categoría de la denuncia',
  'Other concern': 'Otro motivo',
  'Child safety': 'Seguridad infantil',
  'Describe the concern': 'Describe el problema',
  'Report submitted': 'Denuncia enviada',
  'Reason': 'Motivo',
  'Report': 'Denunciar',
  'Cancel': 'Cancelar',
  'Comments': 'Comentarios',
  'No comments yet': 'Todavía no hay comentarios',
  'Be the first to start the conversation.':
      'Sé la primera persona en iniciar la conversación.',
  'Write a comment': 'Escribe un comentario',
  'Send comment': 'Enviar comentario',
  'Organize conversations in your community. Tap a category to edit it.':
      'Organiza las conversaciones de tu comunidad. Toca una categoría para editarla.',
  'Category icon': 'Icono de categoría',
  'Current icon': 'Icono actual',
  'Nature': 'Naturaleza',
  'Pets': 'Mascotas',
  'Announcements': 'Avisos',
  'Category options': 'Opciones de categoría',
  'Choose a short, clear name.': 'Elige un nombre breve y claro.',
  'Enter a category name.': 'Introduce un nombre para la categoría.',
  'What should neighbors post here?': '¿Qué pueden publicar los vecinos aquí?',
  'Choose a category and add text.':
      'Elige una categoría y escribe el contenido.',
  'Tag members': 'Etiquetar miembros',
  'Tagged members receive a notification when the post is published.':
      'Los miembros etiquetados recibirán una notificación cuando se publique.',
  'Tagged members: {count}': 'Miembros etiquetados: {count}',
  'Post submitted for approval': 'Publicación enviada para aprobación',
  'A community moderator will review it before publication.':
      'Un moderador de la comunidad la revisará antes de publicarla.',
  'Done': 'Listo',
  'A post supports up to 10 files.':
      'Una publicación admite hasta 10 archivos.',
  'The file must be under 25 MB.': 'El archivo debe ocupar menos de 25 MB.',
  'No posts need approval': 'No hay publicaciones pendientes de aprobación',
  'Reject': 'Rechazar',
  'Approve': 'Aprobar',
  'No open reports': 'No hay denuncias abiertas',
  'Post {id}': 'Publicación {id}',
  'Dismiss': 'Descartar',
  'Remove post': 'Eliminar publicación',
  'No membership requests': 'No hay solicitudes de ingreso',
  'Now': 'Ahora',
  '{count} min ago': '{count} min',
  '{count} h ago': '{count} h',
  '{count} days ago': '{count} días',
  'Something went wrong. Please try again.':
      'Ha ocurrido un error. Inténtalo de nuevo.',
  'Please sign in again.': 'Vuelve a iniciar sesión.',
  'Media upload failed.': 'No se pudo subir el archivo.',
  'The server returned an invalid response.':
      'El servidor devolvió una respuesta no válida.',
  'The server could not complete the request.':
      'El servidor no pudo completar la solicitud.',
  'Community town data is missing.':
      'Faltan los datos de la ciudad de la comunidad.',
  'Facebook web login is not configured.':
      'El inicio de sesión de Facebook para web no está configurado.',
  'Facebook sign-in was cancelled.':
      'Se canceló el inicio de sesión con Facebook.',
  'Facebook sign-in failed.': 'Falló el inicio de sesión con Facebook.',
  'Unable to sign in to Wicchu.': 'No se pudo iniciar sesión en Wicchu.',
  'Try another search or category.': 'Prueba otra búsqueda o categoría.',
  'Water will be unavailable in the northern area tomorrow morning.':
      'Mañana por la mañana se cortará el agua en la zona norte.',
  'Mountain bike for sale': 'Bicicleta de montaña en venta',
  'Latest update from our community': 'Últimas novedades de nuestra comunidad',
  'Local community for Town X': 'Comunidad local de Town X',
  'Near you': 'Cerca de ti',
  'Joined': 'Miembro',
  'Join': 'Unirse',
  'Popular near you': 'Popular cerca de ti',
  'Animal Lovers': 'Amantes de los animales',
  'Football': 'Fútbol',
  'Students': 'Estudiantes',
  'Cycling': 'Ciclismo',
  'Emoji': 'Emojis',
  'Private conversation': 'Conversación privada',
  'Request to join': 'Solicitar',
  'Requested': 'Solicitado',
  'Today': 'Hoy',
  'Yesterday': 'Ayer',
  'María replied to your post': 'María respondió a tu publicación',
  'Carlos reacted to your post': 'Carlos reaccionó a tu publicación',
  'Your request to join Town X Community was approved':
      'Aprobaron tu solicitud para unirte a Town X Community',
  'New announcement in Town X': 'Nuevo anuncio en Town X',
  '12 minutes ago': 'Hace 12 minutos',
  '35 minutes ago': 'Hace 35 minutos',
  '2 hours ago': 'Hace 2 horas',
  '20 min': 'hace 20 min',
  '43 min': 'hace 43 min',
  '4 Communities · 23 Posts': '4 comunidades · 23 publicaciones',
  'My communities': 'Mis comunidades',
  'My posts': 'Mis publicaciones',
  'Saved posts': 'Publicaciones guardadas',
  'Communities I manage': 'Comunidades que administro',
  'Settings': 'Ajustes',
  'Help': 'Ayuda',
  'or': 'o',
  'Signing in…': 'Iniciando sesión…',
  'Continue with Facebook': 'Continuar con Facebook',
  'Continue with Google': 'Continuar con Google',
  'Continue with Apple': 'Continuar con Apple',
  'Apple sign-in is unavailable.':
      'El inicio de sesión con Apple no está disponible.',
  'Continue with email': 'Continuar con correo electrónico',
  'Sign in with email': 'Iniciar sesión con correo',
  'Sign in': 'Iniciar sesión',
  'Register': 'Registrarse',
  'Create account': 'Crear cuenta',
  'Full name': 'Nombre completo',
  'Username': 'Nombre de usuario',
  'Email address': 'Correo electrónico',
  'Password': 'Contraseña',
  'Delete account': 'Eliminar cuenta',
  'Deleting account…': 'Eliminando cuenta…',
  'Account deleted': 'Cuenta eliminada',
  'Update Wicchu to continue': 'Actualiza Wicchu para continuar',
  'A new Wicchu update is available':
      'Hay una nueva actualización de Wicchu disponible',
  'Version {version} is ready to install.':
      'La versión {version} está lista para instalarse.',
  "What's new": 'Novedades',
  'Later': 'Más tarde',
  'Update now': 'Actualizar ahora',
  'Could not open the store. Please try again.':
      'No se pudo abrir la tienda. Inténtalo de nuevo.',
  'Your Wicchu account and personal content have been permanently deleted. You can create a new account at any time.':
      'Tu cuenta de Wicchu y tu contenido personal se han eliminado permanentemente. Puedes crear una cuenta nueva en cualquier momento.',
  'Continue to sign in': 'Continuar para iniciar sesión',
  'Permanently delete your account and personal content.':
      'Elimina permanentemente tu cuenta y tu contenido personal.',
  'Blocked users': 'Usuarios bloqueados',
  'You have not blocked anyone.': 'No has bloqueado a nadie.',
  'Unblock': 'Desbloquear',
  'Transfer ownership first': 'Transfiere la propiedad primero',
  'You must transfer or delete every space you own before deleting your account.':
      'Debes transferir o eliminar todos los espacios que posees antes de eliminar tu cuenta.',
  'Delete account permanently?': '¿Eliminar la cuenta permanentemente?',
  'This removes your profile, memberships, posts, comments, media, and notifications. This action cannot be undone.':
      'Esto elimina tu perfil, membresías, publicaciones, comentarios, archivos y notificaciones. Esta acción no se puede deshacer.',
  'Password (email accounts only)': 'Contraseña (solo cuentas con correo)',
  'Type DELETE to confirm': 'Escribe DELETE para confirmar',
  'Block user': 'Bloquear usuario',
  'Block this user?': '¿Bloquear a este usuario?',
  'You will no longer see each other’s posts, comments, profiles, mentions, or notifications.':
      'Ya no verán mutuamente sus publicaciones, comentarios, perfiles, menciones ni notificaciones.',
  'Block': 'Bloquear',
  'Confirm password': 'Confirmar contraseña',
  'Passwords do not match.': 'Las contraseñas no coinciden.',
  'Enter your name.': 'Escribe tu nombre.',
  'Use at least 3 characters.': 'Usa al menos 3 caracteres.',
  'Use only letters, numbers, dots, underscores, or hyphens.':
      'Usa solo letras, números, puntos, guiones bajos o guiones.',
  'Enter a valid email address.': 'Escribe un correo electrónico válido.',
  'At least 8 characters': 'Al menos 8 caracteres',
  'Password must be at least 8 characters.':
      'La contraseña debe tener al menos 8 caracteres.',
  'Forgot password?': '¿Olvidaste tu contraseña?',
  'Resend verification': 'Reenviar verificación',
  'If an account exists, a verification email has been sent.':
      'Si existe una cuenta, se ha enviado un correo de verificación.',
  'Reset password': 'Restablecer contraseña',
  'Send reset link': 'Enviar enlace',
  'Check your email': 'Revisa tu correo',
  'We sent you a verification link. Verify your email before signing in.':
      'Te enviamos un enlace de verificación. Verifica tu correo antes de iniciar sesión.',
  'If an account exists, a password reset email has been sent.':
      'Si existe una cuenta, se ha enviado un correo para restablecer la contraseña.',
  'All fields are required': 'Todos los campos son obligatorios',
  'Email already in use': 'El correo electrónico ya está en uso',
  'This email already has an account. Sign in below or reset your password.':
      'Este correo ya tiene una cuenta. Inicia sesión abajo o restablece tu contraseña.',
  'An account already exists with this email. Sign in or reset your password.':
      'Ya existe una cuenta con este correo. Inicia sesión o restablece tu contraseña.',
  'Username already in use': 'El nombre de usuario ya está en uso',
  'Email and password are required':
      'El correo y la contraseña son obligatorios',
  'Enter a valid name and email address':
      'Escribe un nombre y un correo electrónico válidos',
  'Username must be 3 to 40 letters, numbers, dots, underscores, or hyphens':
      'El nombre de usuario debe tener entre 3 y 40 letras, números, puntos, guiones bajos o guiones',
  'Password must be 8 to 128 characters':
      'La contraseña debe tener entre 8 y 128 caracteres',
  'Invalid credentials': 'Credenciales incorrectas',
  'Email not verified. Please verify your email before logging in.':
      'El correo no está verificado. Verifícalo antes de iniciar sesión.',
  'Email not verified. A new verification link has been sent.':
      'El correo no está verificado. Se ha enviado un nuevo enlace de verificación.',
  'Your community, closer.': 'Tu comunidad, más cerca.',
  'By continuing, you agree to Wicchu’s Terms and Privacy Policy.':
      'Al continuar, aceptas los Términos y la Política de privacidad de Wicchu.',
  'Facebook sign-in will be available soon. In the meantime, use Google or email and password.':
      'El inicio de sesión con Facebook estará disponible pronto. Mientras tanto, usa Google o tu correo electrónico y contraseña.',
  'Facebook sign-in is unavailable.':
      'El inicio de sesión con Facebook no está disponible.',
  'Facebook email permission was not granted. Allow email access or register with email.':
      'No se concedió el permiso de correo electrónico de Facebook. Permite el acceso o regístrate con tu correo.',
  'This Facebook account does not provide an email address. Register with a verified email instead.':
      'Esta cuenta de Facebook no proporciona un correo electrónico. Regístrate con un correo verificado.',
  'Use email': 'Usar correo',
  'Google sign-in is unavailable.':
      'El inicio de sesión con Google no está disponible.',
  '{count} members': '{count} miembros',
  '{count} member': '{count} miembro',
  'Community management': 'Administrar comunidad',
  'Share': 'Compartir',
  'Categories': 'Categorías',
  'Latest posts': 'Publicaciones recientes',
  'Sell / Post': 'Vender / Publicar',
  'Post': 'Publicar',
  '1 neighbor online': '1 vecino conectado',
  '{count} neighbors online': '{count} vecinos conectados',
  'Discard changes?': '¿Descartar cambios?',
  'Your profile changes have not been saved.':
      'Los cambios de tu perfil no se han guardado.',
  'Keep editing': 'Seguir editando',
  'Discard': 'Descartar',
  'Enter a phone number with country code.':
      'Introduce un teléfono con prefijo internacional.',
  'Use a valid HTTPS profile link.': 'Usa un enlace de perfil HTTPS válido.',
  'Enter a username or profile link.':
      'Introduce un usuario o enlace de perfil.',
  'Choose how people can contact you from your profile. All fields are optional.':
      'Elige cómo pueden contactarte desde tu perfil. Todos los campos son opcionales.',
  'Include your country code.': 'Incluye el prefijo internacional.',
  'Username or HTTPS profile link': 'Usuario o enlace de perfil HTTPS',
  'Clear a field to remove it from your profile.':
      'Vacía un campo para eliminarlo de tu perfil.',
  'Saving changes…': 'Guardando cambios…',
  'Email': 'Correo electrónico',
  'Select a community': 'Selecciona una comunidad',
  'Find your community': 'Encuentra tu comunidad',
  'Discover communities nearby, join and connect with your neighbors.':
      'Descubre comunidades cerca de ti, únete y conecta con tus vecinos.',
  'Choose a community to see its posts and neighbors.':
      'Elige una comunidad para ver sus publicaciones y vecinos.',
  'Community details': 'Información de la comunidad',
  'View all online neighbors': 'Ver todos los vecinos conectados',
  'Publication': 'Publicación',
  'View my profile': 'Ver mi perfil',
  'My content': 'Mi contenido',
  'Management': 'Gestión',
  'Preferences': 'Preferencias',
  'Profile': 'Perfil',
  'Posts': 'Publicaciones',
  'Edit profile': 'Editar perfil',
  'See more': 'Ver más',
  'See less': 'Ver menos',
  'What do you want to publish?': '¿Qué quieres publicar?',
  'Latest': 'Recientes',
  'Popular': 'Populares',
  'Create post': 'Crear publicación',
  'Type': 'Tipo',
  'Options': 'Opciones',
  'Step {current} of {total}': 'Paso {current} de {total}',
  'Choose a format. You can adjust it later.':
      'Elige un formato. Puedes ajustarlo después.',
  'Standard post': 'Publicación',
  'Share an update, idea, or local news.':
      'Comparte una novedad, una idea o noticias locales.',
  'Photos or video': 'Fotos o vídeo',
  'Tell your story with up to 10 media files.':
      'Cuenta tu historia con hasta 10 archivos multimedia.',
  'Create your content': 'Crea tu contenido',
  'Write your post and add anything it needs.':
      'Escribe tu publicación y añade lo que necesite.',
  'Add photos or video': 'Añadir fotos o vídeo',
  'Poll options': 'Opciones de la encuesta',
  'Review how this post will be published.':
      'Revisa cómo se publicará esta publicación.',
  'Not selected': 'Sin seleccionar',
  'Change': 'Cambiar',
  'Review everything before publishing.': 'Revisa todo antes de publicar.',
  'Next': 'Siguiente',
  'Published': 'Publicado',
  'Your post is live and can now be shared.':
      'Tu publicación ya está visible y puedes compartirla.',
  'View post': 'Ver publicación',
  'Create another post': 'Crear otra publicación',
  'Share elsewhere': 'Compartir también en',
  'Get more reach': 'Consigue más alcance',
  'Instagram Story': 'Historia de Instagram',
  'Instagram Post': 'Publicación de Instagram',
  'Share a Wicchu-designed 9:16 image.':
      'Comparte una imagen 9:16 diseñada por Wicchu.',
  'Share a Wicchu-designed 4:5 image.':
      'Comparte una imagen 4:5 diseñada por Wicchu.',
  'More sharing options': 'Más opciones para compartir',
  'Preparing share…': 'Preparando para compartir…',
  'Caption copied. Paste it in Instagram if needed.':
      'Texto copiado. Pégalo en Instagram si es necesario.',
  'Copy description': 'Copiar descripción',
  'Description copied': 'Descripción copiada',
  'Copy link': 'Copiar enlace',
  'Posting to': 'Publicando en',
  'Post details': 'Detalles de la publicación',
  'What would you like to share?': '¿Qué te gustaría compartir?',
  'Preview': 'Vista previa',
  'Photo': 'Foto',
  'Video': 'Vídeo',
  'Add to your post': 'Añade contenido a tu publicación',
  'Publish': 'Publicar',
  'Publishing…': 'Publicando…',
  'Post published': 'Publicación publicada',
  'Your post is live. Share it with your community elsewhere?':
      'Tu publicación ya está visible. ¿Quieres compartirla también fuera de la comunidad?',
  'Not now': 'Ahora no',
  'Share post': 'Compartir publicación',
  'Share to Instagram or Facebook': 'Compartir en Instagram o Facebook',
  'Create an Instagram or Facebook post':
      'Crear una publicación en Instagram o Facebook',
  'Share Wicchu link': 'Compartir enlace de Wicchu',
  'Preparing media…': 'Preparando contenido…',
  'Exports the original media. Choose the destination in the next screen.':
      'Exporta el contenido original. Elige el destino en la siguiente pantalla.',
  'Caption copied. Choose Instagram or Facebook and paste it if needed.':
      'Texto copiado. Elige Instagram o Facebook y pégalo si es necesario.',
  'Exports only the original media so the social app can open its post composer.':
      'Exporta únicamente el contenido original para que la aplicación social abra su editor de publicaciones.',
  'Caption copied. In Instagram, choose Feed and paste the caption.':
      'Texto copiado. En Instagram, elige Feed y pega el texto.',
  'Bold': 'Negrita',
  'bold text': 'texto en negrita',
  'Italic': 'Cursiva',
  'italic text': 'texto en cursiva',
  'Bulleted list': 'Lista con viñetas',
  'Numbered list': 'Lista numerada',
  'List item': 'Elemento de la lista',
  'Link': 'Enlace',
  'Web address': 'Dirección web',
  'Add': 'Añadir',
  'Remove': 'Quitar',
  'link text': 'texto del enlace',
  'Bring your community together': 'Reúne a tu comunidad',
  'Create an organized place for local news, jobs, events and conversations.':
      'Crea un espacio organizado para noticias, empleos, eventos y conversaciones locales.',
  'Create a community': 'Crear una comunidad',
  'Needs your attention': 'Requiere tu atención',
  'Photos and videos · Max. 10 files': 'Fotos y vídeos · Máx. 10 archivos',
  'Tag': 'Etiquetar',
  '{count} tagged': '{count} etiquetado(s)',
  'Discover new communities': 'Descubre nuevas comunidades',
  'Create your own community': 'Crea tu propia comunidad',
  'Member': 'Miembro',
  'Administrator': 'Administrador',
  'Moderator': 'Moderador',
  'You have no invitations': 'No tienes invitaciones',
  'When someone invites you to a community, the invitation will appear here.':
      'Cuando alguien te invite a una comunidad, la invitación aparecerá aquí.',
  'You haven’t saved any posts yet': 'Aún no has guardado publicaciones',
  'Save posts you want to revisit later.':
      'Guarda publicaciones que quieras consultar más tarde.',
  'Explore posts': 'Explorar publicaciones',
  'About anonymous posting': 'Acerca de las publicaciones anónimas',
  'Shown as Community Admin. Identity retained for auditing.':
      'Aparecerás como Administrador de la comunidad. Tu identidad se conserva para auditoría.',
  'Requires approval. Administrators can identify you.':
      'Requiere aprobación. Los administradores pueden identificarte.',
  'Approval queue': 'Pendientes de aprobación',
  'Pending approval': 'Pendiente de aprobación',
  '{current} of {total} post': '{current} de {total} publicación',
  '{current} of {total} posts': '{current} de {total} publicaciones',
  'Previous post': 'Publicación anterior',
  'Next post': 'Siguiente publicación',
  'Submitted {time}': 'Enviado: {time}',
  'Posts awaiting approval': 'Publicaciones pendientes de aprobación',
  'Reports': 'Denuncias',
  'Membership requests': 'Solicitudes de ingreso',
  'Promote locally': 'Promocionar localmente',
  'Promotion requests': 'Solicitudes de promoción',
  'Your first month is free': 'Tu primer mes es gratis',
  'Help local people discover your business, event, service or useful announcement.':
      'Ayuda a la gente local a descubrir tu negocio, evento, servicio o anuncio útil.',
  '• One active promotion at a time': '• Una promoción activa a la vez',
  '• Up to 7 days per promotion': '• Hasta 7 días por promoción',
  '• One town during your free month': '• Una ciudad durante tu mes gratuito',
  '• No automatic charge afterward': '• Sin cobro automático al finalizar',
  'Trial ends': 'La prueba termina',
  'Your free promotion month has ended.':
      'Tu mes gratuito de promoción ha terminado.',
  'Promote a post for free': 'Promocionar una publicación gratis',
  'Publish a post before creating a promotion.':
      'Publica algo antes de crear una promoción.',
  'Your promotions': 'Tus promociones',
  'You have not promoted a post yet.':
      'Todavía no has promocionado ninguna publicación.',
  'Choose one of your published posts.': 'Elige una de tus publicaciones.',
  'Duration': 'Duración',
  '{count} days': '{count} días',
  'Every promotion is marked Sponsored and requires community approval. No payment is required during the pilot.':
      'Cada promoción se marca como Patrocinada y requiere aprobación de la comunidad. No se requiere pago durante el programa piloto.',
  'Submit for approval': 'Enviar para aprobación',
  'Promotion submitted for approval.': 'Promoción enviada para aprobación.',
  'Impressions': 'Impresiones',
  'Post opens': 'Aperturas de la publicación',
  'Cancel promotion': 'Cancelar promoción',
  'Sponsored': 'Patrocinado',
  'No promotion requests.': 'No hay solicitudes de promoción.',
  'Free local promotion': 'Promoción local gratuita',
  'Post ID': 'ID de publicación',
  'Reject promotion': 'Rechazar promoción',
  'active': 'Activa',
  'rejected': 'Rechazada',
  'completed': 'Completada',
  'cancelled': 'Cancelada',
  'Overview': 'Resumen',
  'Moderation': 'Moderación',
  'Create community': 'Crear comunidad',
  'Continue': 'Continuar',
  'Back': 'Atrás',
  'Basics': 'Datos básicos',
  'Community name': 'Nombre de la comunidad',
  'Short description': 'Descripción breve',
  'Location': 'Ubicación',
  'Town': 'Ciudad',
  'Rules': 'Normas',
  'Approve posts before publishing':
      'Aprobar publicaciones antes de publicarlas',
  'You can change this later by category.':
      'Puedes cambiarlo más adelante por categoría.',
  '{count} categories': '{count} categorías',
  '{count} category': '{count} categoría',
  'Public community · You will be the owner':
      'Comunidad pública · Serás el propietario',
  'Add a community name.': 'Añade un nombre para la comunidad.',
  'Choose a town.': 'Elige una ciudad.',
  'No towns found': 'No se encontraron ciudades',
  'Choose at least one category.': 'Elige al menos una categoría.',
  'Your community is ready!': '¡Tu comunidad está lista!',
  'Invite your first members and start the conversation.':
      'Invita a los primeros miembros y empieza la conversación.',
  'Share invitation': 'Compartir invitación',
  'Invitations': 'Invitaciones',
  'Invite by email': 'Invitar por correo electrónico',
  'Invitations expire after 14 days. Invited members join directly.':
      'Las invitaciones vencen después de 14 días. Los miembros invitados ingresan directamente.',
  'Send invitation': 'Enviar invitación',
  'Invitation history': 'Historial de invitaciones',
  'No invitations yet': 'Todavía no hay invitaciones',
  'No pending invitations': 'No hay invitaciones pendientes',
  'You were invited to join this community.':
      'Te invitaron a unirte a esta comunidad.',
  'Revoke': 'Revocar',
  'Accept': 'Aceptar',
  'Decline': 'Rechazar',
  'pending': 'pendiente',
  'accepted': 'aceptada',
  'declined': 'rechazada',
  'revoked': 'revocada',
  'Helpful to members': 'Útil para los miembros',
  '{percentage}% of members find this community helpful':
      'El {percentage}% de los miembros considera útil esta comunidad',
  '{count} more response is needed to show the community score.':
      'Se necesita {count} respuesta más para mostrar la puntuación de la comunidad.',
  '{count} more responses are needed to show the community score.':
      'Se necesitan {count} respuestas más para mostrar la puntuación de la comunidad.',
  'Based on {count} response': 'Basado en {count} respuesta',
  'Based on {count} responses': 'Basado en {count} respuestas',
  'Do you find this community helpful?': '¿Consideras útil esta comunidad?',
  'Not really': 'No mucho',
  'Thanks for your feedback.': 'Gracias por tu opinión.',
  'Community feedback': 'Opinión sobre la comunidad',
  'Is the information relevant to your local area?':
      '¿La información es relevante para tu zona?',
  'Do you feel safe participating here?':
      '¿Te sientes seguro participando aquí?',
  'Is the community well organized?': '¿La comunidad está bien organizada?',
  'Would you recommend this community to someone nearby?':
      '¿Recomendarías esta comunidad a alguien de tu zona?',
  'Sometimes': 'A veces',
  'Somewhat': 'En parte',
  'Submit': 'Enviar',
  'Answer the short survey': 'Responder la encuesta breve',
  'Invite people': 'Invitar personas',
  'Create and share invitation link': 'Crear y compartir enlace de invitación',
  'Or invite a specific person by email':
      'O invita a una persona específica por correo',
  'Shareable invitation link': 'Enlace de invitación compartible',
  'Community invitation': 'Invitación a la comunidad',
  'You joined the community.': 'Te uniste a la comunidad.',
  'Invitation declined.': 'Invitación rechazada.',
  'Show local weather': 'Mostrar clima local',
  'Display current conditions for the community town.':
      'Muestra las condiciones actuales de la localidad de la comunidad.',
  'Local weather': 'Clima local',
  'Weather is temporarily unavailable.':
      'El clima no está disponible temporalmente.',
  'High {high}° · Low {low}°': 'Máx. {high}° · Mín. {low}°',
  'Provided by': 'Proporcionado por',
  'Updated {time}': 'Actualizado a las {time}',
  'Clear sky': 'Cielo despejado',
  'Mainly clear': 'Mayormente despejado',
  'Partly cloudy': 'Parcialmente nublado',
  'Overcast': 'Nublado',
  'Fog': 'Niebla',
  'Drizzle': 'Llovizna',
  'Rain': 'Lluvia',
  'Heavy rain': 'Lluvia intensa',
  'Snow': 'Nieve',
  'Rain showers': 'Chubascos',
  'Heavy rain showers': 'Chubascos intensos',
  'Snow showers': 'Chubascos de nieve',
  'Thunderstorm': 'Tormenta eléctrica',
  'Current conditions': 'Condiciones actuales',
  'Public exact location': 'Ubicación exacta pública',
  'Hide my identity': 'Ocultar mi identidad',
  'Hide details': 'Ocultar detalles',
  'More information': 'Más información',
  'Official links': 'Enlaces oficiales',
  'Finish by saving changes in settings.':
      'Para terminar, guarda los cambios en los ajustes.',
  'Public website': 'Sitio web público',
  'Copy website address': 'Copiar dirección del sitio web',
  'Website address copied.': 'Dirección del sitio web copiada.',
  'Add link': 'Añadir enlace',
  'Add a website, social network, contact page, or another official link.':
      'Añade un sitio web, red social, página de contacto u otro enlace oficial.',
  'Add official link': 'Añadir enlace oficial',
  'Edit official link': 'Editar enlace oficial',
  'Label': 'Etiqueta',
  'Website, Facebook, WhatsApp…': 'Sitio web, Facebook, WhatsApp…',
  'Anonymous member insights': 'Opiniones anónimas de los miembros',
  'Locally relevant': 'Relevante para la zona',
  'Safe to participate': 'Segura para participar',
  'Well organized': 'Bien organizada',
  'Would recommend': 'La recomendaría',
  'Enter community': 'Entrar en la comunidad',
  'Finding your current town…': 'Buscando tu ciudad actual…',
  'Wicchu needs your location to find your town and nearby communities.':
      'Wicchu necesita tu ubicación para encontrar tu ciudad y comunidades cercanas.',
  'Update my location': 'Actualizar mi ubicación',
  'Use my current location': 'Usar mi ubicación actual',
  'Confirm your current location to continue.':
      'Confirma tu ubicación actual para continuar.',
  'Turn on location services and try again.':
      'Activa los servicios de ubicación e inténtalo de nuevo.',
  'Location permission is blocked. Enable it in your device settings.':
      'El permiso de ubicación está bloqueado. Actívalo en los ajustes del dispositivo.',
  'Location permission is required to create a community.':
      'Se necesita permiso de ubicación para crear una comunidad.',
  'Enable nearby discovery in Settings first.':
      'Activa el descubrimiento cercano en Ajustes primero.',
  'Enable location services to discover nearby communities.':
      'Activa los servicios de ubicación para descubrir comunidades cercanas.',
  'Location permission is required for nearby discovery.':
      'Se necesita permiso de ubicación para descubrir comunidades cercanas.',
  'Show all communities': 'Mostrar todas las comunidades',
  'Use my location': 'Usar mi ubicación',
  'Join {community} on Wicchu': 'Únete a {community} en Wicchu',
  'Join {community} on Wicchu:': 'Únete a {community} en Wicchu:',
  'Notifications': 'Notificaciones',
  'Post activity': 'Actividad de publicaciones',
  'Reactions and comments on your posts':
      'Reacciones y comentarios en tus publicaciones',
  'Community activity': 'Actividad de comunidades',
  'Membership and moderation updates': 'Novedades sobre miembros y moderación',
  'Promotions': 'Promociones',
  'Promotion approval updates': 'Novedades sobre la aprobación de promociones',
  'Update received': 'Actualización recibida',
  'reacted to your post': 'reaccionó a tu publicación',
  'commented on your post': 'comentó tu publicación',
  'mentioned you in a post': 'te mencionó en una publicación',
  'approved your post': 'aprobó tu publicación',
  'rejected your post': 'rechazó tu publicación',
  'removed your post': 'eliminó tu publicación',
  'restored your post': 'restauró tu publicación',
  'approved your comment': 'aprobó tu comentario',
  'rejected your comment': 'rechazó tu comentario',
  'removed your comment': 'eliminó tu comentario',
  'removed you from the community': 'te eliminó de la comunidad',
  'restricted your community membership':
      'restringió tu membresía en la comunidad',
  'restored your community membership': 'restauró tu membresía en la comunidad',
  'Member actions': 'Acciones del miembro',
  'Publish as Community Admin': 'Publicar como administrador de la comunidad',
  'Publish anonymously': 'Publicar de forma anónima',
  'Anonymous posts are always reviewed by a community administrator before publication. Administrators can still identify you for safety.':
      'Las publicaciones anónimas siempre son revisadas por un administrador de la comunidad antes de publicarse. Los administradores aún pueden identificarte por seguridad.',
  'Members will not see your personal profile. Your identity remains available for security and auditing.':
      'Los miembros no verán tu perfil personal. Tu identidad seguirá disponible para seguridad y auditoría.',
  'Community Admin': 'Administrador de la comunidad',
  'Anonymous Member': 'Miembro anónimo',
  'Anonymous administrator identity': 'Identidad de administrador anónima',
  'Members will see Community Admin instead of your profile. Other administrators can still identify you for security and auditing.':
      'Los miembros verán Administrador de la comunidad en lugar de tu perfil. Los demás administradores aún podrán identificarte por seguridad y auditoría.',
  'Remove member': 'Eliminar miembro',
  'Ban member': 'Bloquear miembro',
  'Unban member': 'Desbloquear miembro',
  'Banned': 'Bloqueado',
  'Unban': 'Desbloquear',
  'Member unbanned': 'Miembro desbloqueado',
  'Member removed': 'Miembro eliminado',
  'Member banned': 'Miembro bloqueado',
  'Removed posts': 'Publicaciones eliminadas',
  'Review and restore posts removed by moderators':
      'Revisa y restaura publicaciones eliminadas por moderadores',
  'Restore post': 'Restaurar publicación',
  'Restore': 'Restaurar',
  'Post restored': 'Publicación restaurada',
  'No removed posts': 'No hay publicaciones eliminadas',
  'The post will be published again and its author will be notified.':
      'La publicación volverá a publicarse y se notificará a su autor.',
  'Restoration reason': 'Motivo de la restauración',
  'Explain why the moderation decision is being reversed.':
      'Explica por qué se revierte la decisión de moderación.',
  'Removal reason': 'Motivo de eliminación',
  '{count} media item': '{count} elemento multimedia',
  '{count} media items': '{count} elementos multimedia',
  'This member can request to join the community again.':
      'Este miembro podrá solicitar unirse nuevamente a la comunidad.',
  'This member will regain access to the community.':
      'Este miembro recuperará el acceso a la comunidad.',
  'approved your membership request': 'aprobó tu solicitud de membresía',
  'rejected your membership request': 'rechazó tu solicitud de membresía',
  'approved your promotion': 'aprobó tu promoción',
  'rejected your promotion': 'rechazó tu promoción',
  'removed your post after reviewing a report':
      'eliminó tu publicación después de revisar un reporte',
  'Reply': 'Responder',
  'Write a reply': 'Escribe una respuesta',
  'Replying to {name}': 'Respondiendo a {name}',
  'replied to your comment': 'respondió a tu comentario',
  'liked your comment': 'indicó que le gusta tu comentario',
  'Add poll': 'Añadir votación',
  'Remove poll': 'Quitar votación',
  'Poll': 'Votación',
  'Ask your community a question and let members vote.':
      'Haz una pregunta a tu comunidad y permite que sus miembros voten.',
  'Add option': 'Añadir opción',
  'Remove option': 'Eliminar opción',
  'At least 2 options': 'Mínimo 2 opciones',
  'Option {number}': 'Opción {number}',
  'Add at least two unique poll options.':
      'Añade al menos dos opciones únicas para la votación.',
  '{count} votes': '{count} votos',
  'Member profile': 'Perfil del miembro',
  'All posts': 'Todas las publicaciones',
  'Media': 'Multimedia',
  'Polls': 'Votaciones',
  'Newest': 'Más recientes',
  'Oldest': 'Más antiguas',
  '{posts} posts · {communities} communities':
      '{posts} publicaciones · {communities} comunidades',
  'Social and contact links': 'Redes sociales y contacto',
  'WhatsApp, Facebook, Instagram and email':
      'WhatsApp, Facebook, Instagram y correo electrónico',
  'Profile links saved': 'Enlaces del perfil guardados',
  'Unable to open link': 'No se pudo abrir el enlace',
  'Show online status': 'Mostrar estado en línea',
  'Let members of your communities see when you are online':
      'Permite que los miembros de tus comunidades vean cuándo estás en línea',
  'Online now': 'En línea ahora',
  'Online in your communities': 'En línea en tus comunidades',
  'Neighbors online': 'Vecinos conectados',
  'Neighbors': 'Vecinos',
  'View all': 'Ver todos',
  'Edit post': 'Editar publicación',
  'Edited': 'Editado',
  'Saving…': 'Guardando…',
  'Poll options cannot be changed after voting begins.':
      'Las opciones no se pueden cambiar después de que comience la votación.',
  'Delete publication': 'Eliminar publicación',
  'Delete publication?': '¿Eliminar publicación?',
  'This publication will disappear from Wicchu. This action cannot be undone.':
      'Esta publicación desaparecerá de Wicchu. Esta acción no se puede deshacer.',
  'Community profile': 'Perfil de la comunidad',
  'View community profile': 'Ver perfil de la comunidad',
  'About': 'Información',
  'About this community': 'Acerca de esta comunidad',
  'Details': 'Detalles',
  'No description provided': 'No se proporcionó una descripción',
  'Public community': 'Comunidad pública',
  'Private community': 'Comunidad privada',
  'Created {date}': 'Creada el {date}',
  'The server did not confirm the rules. Your draft is still here; other settings may have saved.':
      'El servidor no confirmó las reglas. Tu borrador sigue aquí; es posible que los otros ajustes se hayan guardado.',
  'Rule changes are applied when you save.':
      'Los cambios en las reglas se aplican al guardar.',
  'Description (optional)': 'Descripción (opcional)',
  'Enter a rule title': 'Escribe un título para la regla',
  'Move down': 'Mover abajo',
  'Move up': 'Mover arriba',
  'Rule actions': 'Opciones de la regla',
  'Help members understand what belongs in this community.':
      'Ayuda a los miembros a entender qué se puede publicar en esta comunidad.',
  'Join to view community posts.':
      'Únete para ver las publicaciones de la comunidad.',
  'Nothing needs your attention.': 'No hay nada que requiera tu atención.',
  'All caught up': 'Todo al día',
  'Content': 'Contenido',
  'People': 'Personas',
  'Security': 'Seguridad',
  'Configuration': 'Configuración',
  'Community activity and key details': 'Actividad y datos de la comunidad',
  'Manage community categories': 'Gestiona las categorías de la comunidad',
  'Define the community rules': 'Define las reglas de la comunidad',
  'Manage community members': 'Gestiona los miembros',
  'Manage community invitations': 'Administra las invitaciones',
  'Review content and manage reports': 'Revisa contenido y gestiona denuncias',
  'Configure your community': 'Configura la comunidad',
  'Community overview': 'Resumen de la comunidad',
  'Current statistics': 'Estadísticas actuales',
  'Open reports': 'Denuncias abiertas',
  'Review pending work in community administration.':
      'Revisa las tareas pendientes en la administración de la comunidad.',
  'Recent posts': 'Publicaciones recientes',
  'No posts yet.': 'Aún no hay publicaciones.',
  'Community information': 'Información de la comunidad',
  'Community cover photo': 'Foto de portada de la comunidad',
  'Community profile photo': 'Foto de perfil de la comunidad',
  'Change cover photo': 'Cambiar foto de portada',
  'Website': 'Sitio web',
  'Other': 'Otro',
  'Telegram, website, Facebook, or other':
      'Telegram, sitio web, Facebook u otro',
  'Tip': 'Consejo',
  'Invite more people to grow your community.':
      'Invita a más personas para hacer crecer tu comunidad.',
  'A better space for everyone': 'Un espacio mejor para todos',
  'These rules help keep your community safe, respectful and active.':
      'Estas reglas ayudan a mantener una comunidad segura, respetuosa y activa.',
  'Rules ({count})': 'Reglas ({count})',
  'Reorder': 'Ordenar',
  'Keep your community safe': 'Mantén tu comunidad segura',
  'Add clear rules so everyone knows how to participate.':
      'Añade reglas claras para que todos sepan cómo participar.',
  'Use clear, specific rules. Tap Reorder to drag rules into place.':
      'Usa reglas claras y específicas. Pulsa Ordenar para reordenarlas arrastrando y soltando.',
  'No community rules yet.': 'Aún no hay reglas para la comunidad.',
  'Active rule': 'Activa',
  'Rule options': 'Opciones de la regla',
  'Everything is in order': 'Todo está en orden',
  'There are no open reports that need your attention.':
      'No hay denuncias abiertas que requieran tu atención.',
  'New reports will appear here for you to review.':
      'Las nuevas denuncias aparecerán aquí para que puedas revisarlas.',
  'Reported by {name}': 'Reportado por {name}',
  'Reported post': 'Publicación reportada',
  'Reported comment': 'Comentario reportado',
  'Reported member': 'Miembro reportado',
  'Reported content is no longer available.':
      'El contenido reportado ya no está disponible.',
  'Report reason': 'Motivo del reporte',
  '{count} media attachments': '{count} archivos multimedia',
  'Wicchu member': 'Miembro de Wicchu',
  'View profile': 'Ver perfil',
  'Set role: {role}': 'Asignar rol: {role}',
  'Search members': 'Buscar miembros',
  'Filter members': 'Filtrar miembros',
  'All members': 'Todos los miembros',
  'Active members': 'Miembros activos',
  'Invite': 'Invitar',
  'Invite more people': 'Invita a más personas',
  'More neighbors, a better community.':
      'Cuantos más vecinos, mejor comunidad.',
  'Sort members': 'Ordenar miembros',
  'No members match your search or filter.':
      'No hay miembros que coincidan con la búsqueda o el filtro.',
  'Offline': 'Sin conexión',
  'Pending': 'Pendiente',
  'Grow your community': 'Haz crecer tu comunidad',
  'Invite neighbors to start connecting and taking part.':
      'Invita a vecinos para empezar a conectar y participar.',
  'Invite members': 'Invitar miembros',
  'An active community is safer, friendlier and more useful for everyone.':
      'Una comunidad activa es más segura, agradable y útil para todos.',
  'Invite people to {community}': 'Invita personas a {community}',
  'Share a link or invite by email. Invitations expire after 14 days.':
      'Comparte el enlace o invita por correo. Las invitaciones vencen después de 14 días.',
  'Invitation link': 'Enlace de invitación',
  'Invite several people with one link.':
      'Invita a varias personas con un solo enlace.',
  'Link options': 'Opciones del enlace',
  'Create new link': 'Crear nuevo enlace',
  'Share link': 'Compartir enlace',
  'Create a link when you are ready to invite people.':
      'Crea un enlace cuando quieras invitar a más personas.',
  'Expires on {date}': 'Caduca el {date}',
  'Active invitations': 'Invitaciones activas',
  'No active invitations.': 'No hay invitaciones activas.',
  'Share the link with your neighbors, on social media or via WhatsApp.':
      'Comparte el enlace con tus vecinos, en redes sociales o por WhatsApp.',
  'Active invitation': 'Activo',
  'Expired': 'Caducada',
  'Created on {date}': 'Creado el {date}',
  'Invitation options': 'Opciones de la invitación',
  'Copy': 'Copiar',
  'Link copied': 'Enlace copiado',
  'Invitation created.': 'Invitación creada.',
  'The invitation link is unavailable. Please try again.':
      'El enlace de invitación no está disponible. Inténtalo de nuevo.',
  'Revoke invitation?': '¿Revocar invitación?',
  'This invitation will no longer allow people to join.':
      'Esta invitación ya no permitirá unirse a la comunidad.',
  'This link is not available to copy. Create a new link to share.':
      'Este enlace no está disponible para copiar. Crea uno nuevo para compartir.',
  'Remove photo': 'Eliminar foto',
  'Use at most {count} characters.': 'Usa un máximo de {count} caracteres.',
  'Manage community': 'Administrar comunidad',
  'Open media {number} of {total}': 'Abrir archivo {number} de {total}',
  'Post options': 'Opciones de la publicación',
  'Previous media': 'Archivo anterior',
  'Next media': 'Archivo siguiente',
  'Swipe to browse media': 'Desliza para ver más',
  'Pinch or double-tap to zoom': 'Pellizca o toca dos veces para ampliar',
  'Could not load media': 'No se pudo cargar el archivo',
  'Pause video': 'Pausar vídeo',
  'Play video': 'Reproducir vídeo',
  'Community rules': 'Reglas de la comunidad',
  'No community rules have been added yet.':
      'Aún no se han añadido reglas para la comunidad.',
  'Join to view community members.':
      'Únete para ver los miembros de la comunidad.',
  'Join to view community media.':
      'Únete para ver el contenido multimedia de la comunidad.',
  'No media yet': 'Aún no hay contenido multimedia',
  'requested to join your community': 'solicitó unirse a tu comunidad',
  'submitted a post for review': 'envió una publicación para revisión',
  'edited a post that needs review':
      'editó una publicación que necesita revisión',
  'submitted a comment for review': 'envió un comentario para revisión',
  'reported a post': 'reportó una publicación',
  'Add rule': 'Añadir regla',
  'Edit rule': 'Editar regla',
  'Delete rule': 'Eliminar regla',
  'Delete rule?': '¿Eliminar regla?',
  'Rule title': 'Título de la regla',
  'Members will no longer see this rule. They will need to accept the updated rules.':
      'Los miembros dejarán de ver esta regla y deberán aceptar las reglas actualizadas.',
  'Add clear rules so members know what is expected in this community.':
      'Añade reglas claras para que los miembros sepan qué se espera en esta comunidad.',
  'Accept rules': 'Aceptar reglas',
  'Rules accepted': 'Reglas aceptadas',
  'Active recently': 'Activo recientemente',
  'Privacy': 'Privacidad',
  'Nearby discovery': 'Descubrimiento cercano',
  'Allow location use when you request nearby communities':
      'Permitir el uso de la ubicación al buscar comunidades cercanas',
  'Account security': 'Seguridad de la cuenta',
  'Facebook account': 'Cuenta de Facebook',
  'Connected': 'Conectada',
  'Connect Facebook for future sign-ins':
      'Conecta Facebook para futuros inicios de sesión',
  'Facebook account connected.': 'Cuenta de Facebook conectada.',
  'Account already exists': 'La cuenta ya existe',
  'A Wicchu account already uses this email. Sign in with email first, then connect Facebook from Settings.':
      'Una cuenta de Wicchu ya usa este correo. Primero inicia sesión con correo y después conecta Facebook desde Configuración.',
  'A Wicchu account already uses this email. Continue with Google, then connect Facebook from Settings.':
      'Una cuenta de Wicchu ya usa este correo. Continúa con Google y después conecta Facebook desde Configuración.',
  'A Wicchu account already uses this email. Continue with Apple, then connect Facebook from Settings.':
      'Una cuenta de Wicchu ya usa este correo. Continúa con Apple y después conecta Facebook desde Configuración.',
  'A Wicchu account already uses this email. Continue with Facebook instead.':
      'Una cuenta de Wicchu ya usa este correo. Continúa con Facebook.',
  'A Wicchu account already uses this email. Continue with Apple instead.':
      'Una cuenta de Wicchu ya usa este correo. Continúa con Apple.',
  'A Wicchu account already uses this email. Sign in with email instead.':
      'Una cuenta de Wicchu ya usa este correo. Inicia sesión con correo.',
  'Confirm your identity': 'Confirma tu identidad',
  'Messages': 'Mensajes',
  'Chats': 'Chats',
  'Requests': 'Solicitudes',
  'No message requests': 'No hay solicitudes de mensajes',
  'New conversations from other people will appear here.':
      'Las conversaciones nuevas de otras personas aparecerán aquí.',
  'Message request pending': 'Solicitud de mensaje pendiente',
  'Accept this request to continue the conversation.':
      'Acepta esta solicitud para continuar la conversación.',
  'Message request sent. You can send more after it is accepted.':
      'Solicitud enviada. Podrás enviar más mensajes cuando sea aceptada.',
  'Waiting for acceptance': 'Esperando aceptación',
  'This conversation is unavailable.': 'Esta conversación no está disponible.',
  'This conversation is unavailable': 'Esta conversación no está disponible',
  'This message request is no longer available':
      'Esta solicitud de mensaje ya no está disponible',
  'This message request is no longer pending':
      'Esta solicitud de mensaje ya no está pendiente',
  'Wait for this person to accept your message request':
      'Espera a que esta persona acepte tu solicitud de mensaje',
  'Message': 'Mensaje',
  'Private conversations': 'Conversaciones privadas',
  'No messages yet': 'Aún no hay mensajes',
  'Open a member profile and tap Message to start a conversation.':
      'Abre el perfil de un miembro y toca Mensaje para iniciar una conversación.',
  'Start the conversation': 'Inicia la conversación',
  'Write a message': 'Escribe un mensaje',
  'Send': 'Enviar',
  'Say hello': 'Di hola',
  'Report message': 'Reportar mensaje',
  'Direct message': 'Mensaje directo',
  'Direct messages': 'Mensajes directos',
  'Warn user': 'Advertir al usuario',
  'Remove message': 'Eliminar mensaje',
  'Load older messages': 'Cargar mensajes anteriores',
  'Delete conversation': 'Eliminar conversación',
  'Delete conversation?': '¿Eliminar conversación?',
  'This removes the conversation from your account only.':
      'Esto elimina la conversación solamente de tu cuenta.',
  'Delete for me': 'Eliminar para mí',
  'Delete for everyone': 'Eliminar para todos',
  'Message removed': 'Mensaje eliminado',
  'Typing…': 'Escribiendo…',
  'Who can message me': 'Quién puede enviarme mensajes',
  'Everyone': 'Todos',
  'People in my communities': 'Personas de mis comunidades',
  'Nobody': 'Nadie',
  'Only people who share a community with you can start a new conversation.':
      'Solo las personas que comparten una comunidad contigo pueden iniciar una conversación nueva.',
  'You will no longer be able to see or send messages in this conversation.':
      'Ya no podrás ver ni enviar mensajes en esta conversación.',
  'Authentication credentials are stored securely on this device.':
      'Las credenciales de acceso se guardan de forma segura en este dispositivo.',
  'Data deletion': 'Eliminación de datos',
  'Visit wicchu.com/data-deletion to request deletion.':
      'Visita wicchu.com/data-deletion para solicitar la eliminación.',
  'How do I join a community?': '¿Cómo me uno a una comunidad?',
  'Open Explore, select a community, and tap Join. Private communities require administrator approval.':
      'Abre Explorar, selecciona una comunidad y toca Unirme. Las comunidades privadas requieren la aprobación de un administrador.',
  'How do I report a post?': '¿Cómo denuncio una publicación?',
  'Tap the flag on a post, enter a reason, and submit it to the community moderators.':
      'Toca la bandera de una publicación, escribe el motivo y envíalo a los moderadores de la comunidad.',
  'How is my location used?': '¿Cómo se usa mi ubicación?',
  'Location is requested only when you choose nearby discovery and is sent to the server to find communities within the selected radius.':
      'La ubicación se solicita solo cuando eliges el descubrimiento cercano y se envía al servidor para buscar comunidades dentro del radio seleccionado.',
  'Support': 'Soporte',
  'Contact the Wicchu support team through wicchu.com.':
      'Contacta con el equipo de soporte de Wicchu a través de wicchu.com.',
  'Add category': 'Añadir categoría',
  'Edit category': 'Editar categoría',
  'No categories': 'No hay categorías',
  'Delete': 'Eliminar',
  'Delete category?': '¿Eliminar categoría?',
  'Existing posts in {category} will remain, but the category will no longer be available.':
      'Las publicaciones existentes en {category} permanecerán, pero la categoría dejará de estar disponible.',
  'Name': 'Nombre',
  'Biography': 'Biografía',
  'Tell people about you, your interests, or what makes you special…':
      'Cuéntanos algo sobre ti, tus intereses o lo que te hace especial…',
  'Name is required.': 'El nombre es obligatorio.',
  'Use 80 characters or fewer.': 'Usa 80 caracteres o menos.',
  'Use 3–30 letters, numbers, periods, or underscores.':
      'Usa entre 3 y 30 letras, números, puntos o guiones bajos.',
  'This username is already taken.': 'Este nombre de usuario ya está en uso.',
  'Use 500 characters or fewer.': 'Usa 500 caracteres o menos.',
  'Use 120 characters or fewer.': 'Usa 120 caracteres o menos.',
  'Description': 'Descripción',
  'Save': 'Guardar',
  'Community settings': 'Ajustes de la comunidad',
  'Visibility': 'Visibilidad',
  'Require post approval': 'Requerir aprobación de publicaciones',
  'Post approval': 'Aprobación de publicaciones',
  'Open comments': 'Abrir comentarios',
  'Required': 'Obligatoria',
  'Automatic': 'Automática',
  'public': 'Pública',
  'private': 'Privada',
  'admin': 'Administrador',
  'moderator': 'Moderador',
  'member': 'Miembro',
  'Your identity in this community': 'Tu identidad en esta comunidad',
  'Show me as an administrator': 'Mostrarme como administrador',
  'Members will see “Community Admin”. Other administrators can identify you.':
      'Los miembros verán «Administrador de la comunidad». Otros administradores podrán identificarte.',
  'Saved automatically': 'Guardado automáticamente',
  'This setting saves automatically.': 'Este ajuste se guarda automáticamente.',
  'Change community photo': 'Cambiar foto de la comunidad',
  'Loading…': 'Cargando…',
  '“Community Admin” will appear instead of your name. Your identity remains available for security and auditing.':
      'Se mostrará «Administrador de la comunidad» en lugar de tu nombre. Tu identidad seguirá disponible para seguridad y auditoría.',
  'Hide my identity from members': 'Ocultar mi identidad a los miembros',
  'When enabled, members will see “Community Admin” instead of your name and photo in this community. Other administrators can still identify you.':
      'Al activarlo, los miembros verán «Administrador de la comunidad» en lugar de tu nombre y foto en esta comunidad. Otros administradores podrán identificarte.',
  'Account and app': 'Cuenta y aplicación',
  "How can we help you?": "¿Cómo podemos ayudarte?",
  "Find answers about Wicchu.": "Encuentra respuestas sobre Wicchu.",
  "Search help…": "Buscar en ayuda…",
  "Frequently asked questions": "Preguntas frecuentes",
  "Need more help?": "¿Necesitas más ayuda?",
  "Contact the support team": "Contacta con el equipo de soporte",
  "Can’t find the answer? Contact the Wicchu team through wicchu.com.":
      "¿No encuentras la respuesta? Contacta con el equipo de Wicchu a través de wicchu.com.",
  "Contact support": "Contactar con soporte",
  "Find more information on our website: wicchu.com.":
      "Puedes encontrar más información en nuestra web: wicchu.com.",
  "No answers found. Try another search or contact support.":
      "No encontramos respuestas. Prueba otra búsqueda o contacta con soporte.",
  "Could not open the support website. Please visit wicchu.com/support.":
      "No se pudo abrir la web de soporte. Visita wicchu.com/support.",
  "Open the post’s options menu, select Report, enter a reason, and submit it to the community moderators.":
      "Abre el menú de opciones de la publicación, selecciona Denunciar, escribe el motivo y envíalo a los moderadores de la comunidad.",
  'Clear search': 'Borrar búsqueda',
  "All notifications": "Todas",
  "Unread": "No leídas",
  "This week": "Esta semana",
  "Earlier": "Más antiguas",
  "You’re all caught up": "Estás al día",
  "You have no new notifications.": "No tienes notificaciones nuevas.",
  "We’ll let you know when there is relevant activity.":
      "Te avisaremos cuando haya actividad relevante.",
  "Checking pending work…": "Comprobando tareas pendientes…",
  "Retry status": "Reintentar estado",
  "{count} pending action": "{count} acción pendiente",
  "{count} pending actions": "{count} acciones pendientes",
  "Manage the communities you administer.":
      "Gestiona las comunidades donde eres administrador.",
  "You don’t manage any communities yet. Create one to get started.":
      "Aún no administras ninguna comunidad. Crea una para empezar.",
  "Keep your community active by reviewing posts and membership requests regularly.":
      "Mantén tu comunidad activa revisando publicaciones y solicitudes de miembros regularmente.",
  'Create': 'Crear',
  'Choose which activity you receive.': 'Elige qué actividad quieres recibir.',
  'Control your information and visibility.':
      'Controla tu información y visibilidad.',
  'About the app': 'Sobre la aplicación',
  'Connect with the communities you belong to.':
      'Conecta con las comunidades a las que perteneces.',
  'Open a community to read posts, discover events and connect with your neighbors.':
      'Abre una comunidad para leer publicaciones, descubrir eventos y conectar con tus vecinos.',
  'Create a public profile': 'Crear un perfil público',
  'For neighborhoods and local groups': 'Para barrios y grupos locales',
  'For businesses, creators, clubs, and organizations':
      'Para negocios, creadores, clubes y organizaciones',
  'Create a community or profile': 'Crear una comunidad o perfil',
  'Bring people together or share your updates':
      'Reúne a personas o comparte tus novedades',
  'What would you like to create?': '¿Qué te gustaría crear?',
  'Choose the type of space that best fits your needs.':
      'Elige el tipo de espacio que mejor se adapte a tus necesidades.',
  'Members join and participate together.':
      'Los miembros se unen y participan juntos.',
  'People follow a person, business, creator or organization.':
      'Las personas siguen a una persona, negocio, creador u organización.',
  'Profile details': 'Detalles del perfil',
  'Tell people what your space is about…': 'Cuenta de qué trata tu espacio…',
  'A clear name and description help people find and join your community.':
      'Un nombre y una descripción claros ayudan a encontrar tu comunidad y unirse a ella.',
  'A clear name and description help people find and follow your profile.':
      'Un nombre y una descripción claros ayudan a encontrar y seguir tu perfil.',
  'Welcome to Wicchu': 'Te damos la bienvenida a Wicchu',
  'Connect with communities and people around you.':
      'Conecta con comunidades y personas de tu entorno.',
  'Stay connected with the communities and people that matter to you.':
      'Mantén el contacto con las comunidades y personas que te importan.',
  'Passwords match': 'Las contraseñas coinciden',
  'Strong password': 'Contraseña segura',
  'Medium password strength': 'Seguridad de contraseña media',
  'Weak password': 'Contraseña débil',
  'New to Wicchu?': '¿Nuevo en Wicchu?',
  'Create an account and start exploring.':
      'Crea una cuenta y empieza a explorar.',
  'By creating an account, you agree to Wicchu’s':
      'Al crear una cuenta, aceptas los documentos de Wicchu:',
  'Terms of Service': 'Términos del servicio',
  'Privacy Policy': 'Política de privacidad',
  'Could not open the page. Please try again.':
      'No se pudo abrir la página. Inténtalo de nuevo.',
  'Your spaces': 'Tus espacios',
  'Switch between your communities and profiles.':
      'Cambia entre tus comunidades y perfiles.',
  'Explore spaces': 'Explorar espacios',
  'Discover new communities and profiles':
      'Descubre nuevas comunidades y perfiles',
  'Discover communities and public profiles around you.':
      'Descubre comunidades y perfiles públicos cerca de ti.',
  'Public profiles': 'Perfiles públicos',
  'Search spaces': 'Buscar espacios',
  'Create a space': 'Crear un espacio',
  'Community': 'Comunidad',
  'Business or public page': 'Negocio o página pública',
  'For businesses, organizations, clubs, services, and projects. People will follow this page.':
      'Para negocios, organizaciones, clubes, servicios y proyectos. Las personas seguirán esta página.',
  'For towns, neighborhoods, associations, and local groups. People will join as members.':
      'Para pueblos, barrios, asociaciones y grupos locales. Las personas se unirán como miembros.',
  'Add a page name.': 'Añade un nombre para la página.',
  'Page name': 'Nombre de la página',
  'Create business or public page': 'Crear negocio o página pública',
  'Publishing': 'Publicaciones',
  'Your updates will appear in one clear profile feed.':
      'Tus novedades aparecerán en un perfil público organizado.',
  'Review your business or public page before creating it.':
      'Revisa tu negocio o página pública antes de crearla.',
  'Public page · You will be the owner':
      'Página pública · Tú serás el propietario',
  'Followers can see and interact with your posts.':
      'Los seguidores pueden ver e interactuar con tus publicaciones.',
  'Followers': 'Seguidores',
  'Follow': 'Seguir',
  'Manage business': 'Administrar negocio',
  'Business settings': 'Ajustes del negocio',
  'Profile settings': 'Ajustes del perfil',
  'Page activity and key details': 'Actividad y datos de la página',
  'Manage page categories': 'Gestiona las categorías de la página',
  'Define the page rules': 'Define las reglas de la página',
  'Manage followers': 'Gestiona los seguidores',
  'Manage page invitations': 'Administra las invitaciones de la página',
  'Configure your page': 'Configura tu página',
  'Page cover photo': 'Foto de portada de la página',
  'Change page photo': 'Cambiar foto de la página',
  'Page overview': 'Resumen de la página',
  'Business rating': 'Valoración del negocio',
  'Profile rating': 'Valoración del perfil',
  'Business rules': 'Reglas del negocio',
  'Profile rules': 'Reglas del perfil',
  'No business rules have been added yet.':
      'Aún no se han añadido reglas del negocio.',
  'No profile rules have been added yet.':
      'Aún no se han añadido reglas del perfil.',
  'Do you find this business helpful?': '¿Te resulta útil este negocio?',
  'Do you find this profile helpful?': '¿Te resulta útil este perfil?',
  '{percentage}% of followers find this business helpful':
      'El {percentage}% de los seguidores considera útil este negocio',
  '{percentage}% of followers find this profile helpful':
      'El {percentage}% de los seguidores considera útil este perfil',
  '{count} more response is needed to show the business score.':
      'Se necesita {count} respuesta más para mostrar la puntuación del negocio.',
  '{count} more responses are needed to show the business score.':
      'Se necesitan {count} respuestas más para mostrar la puntuación del negocio.',
  '{count} more response is needed to show the profile score.':
      'Se necesita {count} respuesta más para mostrar la puntuación del perfil.',
  '{count} more responses are needed to show the profile score.':
      'Se necesitan {count} respuestas más para mostrar la puntuación del perfil.',
  'Business feedback': 'Opiniones sobre el negocio',
  'Profile feedback': 'Opiniones sobre el perfil',
  'Is the business page well organized?':
      '¿Está bien organizada la página del negocio?',
  'Is the profile well organized?': '¿Está bien organizado el perfil?',
  'Would you recommend this business to someone nearby?':
      '¿Recomendarías este negocio a alguien de tu zona?',
  'Would you recommend this profile to someone nearby?':
      '¿Recomendarías este perfil a alguien de tu zona?',
  'Anonymous follower insights': 'Opiniones anónimas de los seguidores',
  'Search communities, businesses or people…':
      'Buscar comunidades, negocios o personas…',
  'Discovery filters': 'Filtros de exploración',
  'Businesses': 'Negocios',
  'Show': 'Mostrar',
  'Created': 'Fecha de creación',
  'Any time': 'Cualquier fecha',
  'Last 24 hours': 'Últimas 24 horas',
  'Last 7 days': 'Últimos 7 días',
  'Last 30 days': 'Últimos 30 días',
  'Insights': 'Estadísticas',
  'Community Insights': 'Estadísticas de la comunidad',
  'Understand community growth and engagement':
      'Comprende el crecimiento y la participación de la comunidad',
  'Members': 'Miembros',
  '+{count} in the last 30 days': '+{count} en los últimos 30 días',
  '{change}% compared with the previous period':
      '{change}% frente al período anterior',
  'Monthly active': 'Activos mensuales',
  'Weekly active': 'Activos semanales',
  'Monthly activity rate': 'Tasa de actividad mensual',
  'Member growth': 'Crecimiento de miembros',
  'Member growth over the last 30 days':
      'Crecimiento de miembros durante los últimos 30 días',
  'Reactions': 'Reacciones',
  'Last 90 days': 'Últimos 90 días',
  'Members / followers': 'Miembros / seguidores',
  'Any number': 'Cualquier cantidad',
  'Fewer than 50': 'Menos de 50',
  '500 or more': '500 o más',
  'Apply filters': 'Aplicar filtros',
  'Reset filters': 'Restablecer filtros',
  'No spaces match these filters.':
      'No hay espacios que coincidan con estos filtros.',
  'Adjust filters': 'Ajustar filtros',
  'My spaces': 'Mis espacios',
  'Spaces I manage': 'Espacios que administro',
  '{count} space': '{count} espacio',
  '{count} spaces': '{count} espacios',
  'No spaces in this section yet.': 'Aún no hay espacios en esta sección.',
  'No spaces available for publishing.':
      'No tienes espacios en los que puedas publicar.',
  'You do not have permission to publish in this space.':
      'No tienes permiso para publicar en este espacio.',
  'Business profile photo': 'Foto de perfil del negocio',
  'Profile photo': 'Foto de perfil',
  'The photo must be under 10 MB.': 'La foto debe ocupar menos de 10 MB.',
  'Main services': 'Servicios principales',
  'Choose up to 10 services that describe your business.':
      'Elige hasta 10 servicios que describan tu negocio.',
  "Today's menu": 'Menú del día',
  "Today's menus": 'Menús del día',
  'Publish dishes, prices and availability for today.':
      'Publica platos, precios y disponibilidad para hoy.',
  'This menu automatically expires tonight.':
      'Este menú caduca automáticamente esta noche.',
  'Dish': 'Plato',
  'Price': 'Precio',
  'Available today': 'Disponible hoy',
  'Available options': 'Opciones disponibles',
  'Add dish': 'Añadir plato',
  'Delivery': 'Entrega a domicilio',
  'Pickup': 'Recogida',
  'Eat in': 'Comer en el local',
  'Restaurant settings': 'Configuración del restaurante',
  'Opening hours, contact and delivery options':
      'Horario, contacto y opciones de entrega',
  'Opening hours': 'Horario de atención',
  'Service options': 'Opciones de servicio',
  'Phone number': 'Número de teléfono',
  'WhatsApp number': 'Número de WhatsApp',
  'Contact business': 'Contactar al negocio',
  'Departed': 'Salió',
  '{views} views · {contacts} contact taps':
      '{views} vistas · {contacts} contactos',
  'Include the international country code.':
      'Incluye el prefijo internacional del país.',
  'Apply settings': 'Aplicar configuración',
  'Open now': 'Abierto ahora',
  'Closed now': 'Cerrado ahora',
  'Closed today': 'Cerrado hoy',
  'Hours not provided': 'Horario no indicado',
  'Call': 'Llamar',
  'Product or offer': 'Producto u oferta',
  'Offers': 'Ofertas',
  'Trips': 'Viajes',
  'Properties': 'Propiedades',
  'Share a product, price and availability.':
      'Comparte un producto, precio y disponibilidad.',
  'Trip availability': 'Viaje disponible',
  'Share a route, departure time and available seats.':
      'Comparte una ruta, hora de salida y asientos disponibles.',
  'Property listing': 'Anuncio de propiedad',
  'Publish a property for rent or sale.':
      'Publica una propiedad en alquiler o venta.',
  'Professional service': 'Servicio profesional',
  'Describe a service, area and starting price.':
      'Describe el servicio, la zona y el precio inicial.',
  'Product or offer name': 'Nombre del producto u oferta',
  'Property title': 'Título de la propiedad',
  'Service name': 'Nombre del servicio',
  'Departure location': 'Lugar de salida',
  'Destination': 'Destino',
  'Departure time': 'Hora de salida',
  'Available seats': 'Asientos disponibles',
  'Listing type': 'Tipo de anuncio',
  'For rent': 'En alquiler',
  'For sale': 'En venta',
  'Bedrooms': 'Dormitorios',
  'Property location': 'Ubicación de la propiedad',
  'Service area': 'Zona de servicio',
  'Starting price (optional)': 'Precio inicial (opcional)',
  'Currently available': 'Disponible actualmente',
  'Delivery and pickup': 'Entrega y recogida',
  'Unavailable': 'No disponible',
  '{count} seats available': '{count} asientos disponibles',
  '{count} bedrooms': '{count} dormitorios',
  'Open the business profile to request a quote.':
      'Abre el perfil del negocio para solicitar un presupuesto.',
  'Monday': 'Lunes',
  'Tuesday': 'Martes',
  'Wednesday': 'Miércoles',
  'Thursday': 'Jueves',
  'Friday': 'Viernes',
  'Saturday': 'Sábado',
  'Sunday': 'Domingo',
  'Following': 'Siguiendo',
  'Unfollow': 'Dejar de seguir',
  'Profile information': 'Información del perfil',
  'Profile type': 'Tipo de perfil',
  '{count} follower': '{count} seguidor',
  '{count} followers': '{count} seguidores',
  'Follow to view followers.': 'Sigue el perfil para ver sus seguidores.',
  'Review your business or public page': 'Revisa tu negocio o página pública',
  'Your business or public page is ready!':
      '¡Tu negocio o página pública está listo!',
  'Share your profile and publish your first update.':
      'Comparte tu perfil y publica tu primera novedad.',
  'Open profile': 'Abrir perfil',
  'Follow {community} on Wicchu': 'Sigue a {community} en Wicchu',
  'Follow {community} on Wicchu:': 'Sigue a {community} en Wicchu:',
  'Monetization': 'Monetización',
  'Monetization unlocked': 'Monetización desbloqueada',
  'Eligible': 'Elegible',
  'Not yet eligible': 'Aún no elegible',
  'Build an active community to unlock earning opportunities from local promotions.':
      'Construye una comunidad activa para desbloquear oportunidades de ingresos con promociones locales.',
  'Your community is eligible for earning opportunities from local promotions.':
      'Tu comunidad cumple los requisitos para obtener ingresos con promociones locales.',
  'Monthly active members': 'Miembros activos mensuales',
  'Community status': 'Estado de la comunidad',
  'Good standing': 'En regla',
  'Restricted': 'Restringida',
  '{members} members and {active} active members to go':
      'Faltan {members} miembros y {active} miembros activos',
  'Start earning from local promotions':
      'Empieza a obtener ingresos con promociones locales',
};
