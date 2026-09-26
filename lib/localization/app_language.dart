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
  'Language': 'Idioma',
  'Appearance': 'Apariencia',
  'System': 'Sistema',
  'Light': 'Claro',
  'Dark': 'Oscuro',
  'Home': 'Inicio',
  'Explore': 'Explorar',
  'Activity': 'Actividad',
  'Communities': 'Comunidades',
  'You': 'Tú',
  'Close search': 'Cerrar búsqueda',
  'Search posts': 'Buscar publicaciones',
  'Search communities': 'Buscar comunidades',
  'Retry': 'Reintentar',
  'New post': 'Nueva publicación',
  'Your town': 'Tu ciudad',
  'Choose a town': 'Elige una ciudad',
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
  'Step {current} of {total}': 'Paso {current} de {total}',
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
  'No posts found': 'No se encontraron publicaciones',
  'Post unavailable': 'Publicación no disponible',
  'No categories found': 'No se encontraron categorías',
  'No communities found': 'No se encontraron comunidades',
  'No activity yet': 'Todavía no hay actividad',
  'Mark all read': 'Marcar todo como leído',
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
  'About {name}': 'Acerca de {name}',
  'Community rating': 'Valoración de la comunidad',
  'Useful links': 'Enlaces útiles',
  'Directions': 'Cómo llegar',
  'Unable to open link. Please try again.':
      'No se pudo abrir el enlace. Inténtalo de nuevo.',
  'Enter a rule title.': 'Introduce un título para la regla.',
  'Describe this rule.': 'Describe esta regla.',
  'Share profile': 'Compartir perfil',
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
  '{count} min ago': 'Hace {count} min',
  '{count} h ago': 'Hace {count} h',
  '{count} days ago': 'Hace {count} días',
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
  'Continue with email': 'Continuar con correo electrónico',
  'Sign in with email': 'Iniciar sesión con correo',
  'Sign in': 'Iniciar sesión',
  'Register': 'Registrarse',
  'Create account': 'Crear cuenta',
  'Full name': 'Nombre completo',
  'Username': 'Nombre de usuario',
  'Email address': 'Correo electrónico',
  'Password': 'Contraseña',
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
  'Community': 'Comunidad',
  'Overview': 'Resumen',
  'Members': 'Miembros',
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
  'Official links': 'Enlaces oficiales',
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
  'Authentication credentials are stored securely on this device.':
      'Las credenciales de acceso se guardan de forma segura en este dispositivo.',
  'Data deletion': 'Eliminación de datos',
  'Visit hexora.dev/wicchu/data-deletion to request deletion.':
      'Visita hexora.dev/wicchu/data-deletion para solicitar la eliminación.',
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
  'Contact the Wicchu support team through hexora.dev.':
      'Contacta con el equipo de soporte de Wicchu a través de hexora.dev.',
  'Add category': 'Añadir categoría',
  'Edit category': 'Editar categoría',
  'No categories': 'No hay categorías',
  'Delete': 'Eliminar',
  'Delete category?': '¿Eliminar categoría?',
  'Existing posts in {category} will remain, but the category will no longer be available.':
      'Las publicaciones existentes en {category} permanecerán, pero la categoría dejará de estar disponible.',
  'Name': 'Nombre',
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
  "Can’t find the answer? Contact the Wicchu team through hexora.dev.":
      "¿No encuentras la respuesta? Contacta con el equipo de Wicchu a través de hexora.dev.",
  "Contact support": "Contactar con soporte",
  "Find more information on our website: hexora.dev.":
      "Puedes encontrar más información en nuestra web: hexora.dev.",
  "No answers found. Try another search or contact support.":
      "No encontramos respuestas. Prueba otra búsqueda o contacta con soporte.",
  "Could not open the support website. Please visit hexora.dev.":
      "No se pudo abrir la web de soporte. Visita hexora.dev.",
  "Open the post’s options menu, select Report, enter a reason, and submit it to the community moderators.":
      "Abre el menú de opciones de la publicación, selecciona Denunciar, escribe el motivo y envíalo a los moderadores de la comunidad.",
  'Clear search': 'Borrar búsqueda',
  "All notifications": "Todas",
  "Unread": "No leídas",
  "This week": "Esta semana",
  "Earlier": "Anteriores",
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
};
