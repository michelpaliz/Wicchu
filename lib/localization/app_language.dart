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

  String trError(Object error) {
    final message = error.toString();
    if (!isSpanish) return message;
    return _spanish[message] ?? tr('Something went wrong. Please try again.');
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
  'You': 'Tú',
  'Close search': 'Cerrar búsqueda',
  'Search posts': 'Buscar publicaciones',
  'Search communities': 'Buscar comunidades',
  'Retry': 'Reintentar',
  'New post': 'Nueva publicación',
  'Your town': 'Tu ciudad',
  'YOUR NEIGHBORHOOD': 'TU VECINDARIO',
  'Good things happen nearby.': 'Lo bueno pasa cerca de ti.',
  'The latest from {town} and your communities.':
      'Lo último de {town} y tus comunidades.',
  'Your communities': 'Tus comunidades',
  'Join a community to see local updates here.':
      'Únete a una comunidad para ver novedades locales aquí.',
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
  '{communities} Communities · {posts} Posts':
      '{communities} comunidades · {posts} publicaciones',
  '{count} community': '{count} comunidad',
  '{count} communities': '{count} comunidades',
  '{count} post': '{count} publicación',
  '{count} posts': '{count} publicaciones',
  'Owner': 'Propietario',
  'Save post': 'Guardar publicación',
  'Unsave post': 'Quitar de guardados',
  'Report post': 'Denunciar publicación',
  'Report submitted': 'Denuncia enviada',
  'Reason': 'Motivo',
  'Report': 'Denunciar',
  'Cancel': 'Cancelar',
  'Comments': 'Comentarios',
  'No comments yet': 'Todavía no hay comentarios',
  'Write a comment': 'Escribe un comentario',
  'Choose a category and add text.':
      'Elige una categoría y escribe el contenido.',
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
  'Continue with Facebook': 'Continuar con Facebook',
  'Your community, closer.': 'Tu comunidad, más cerca.',
  'By continuing, you agree to Wicchu’s Terms and Privacy Policy.':
      'Al continuar, aceptas los Términos y la Política de privacidad de Wicchu.',
  'Facebook sign-in is unavailable.':
      'El inicio de sesión con Facebook no está disponible.',
  '{count} members': '{count} miembros',
  '{count} member': '{count} miembro',
  'Community management': 'Administrar comunidad',
  'Share': 'Compartir',
  'Categories': 'Categorías',
  'Latest posts': 'Publicaciones recientes',
  'Sell / Post': 'Vender / Publicar',
  'Post': 'Publicar',
  'Latest': 'Recientes',
  'Popular': 'Populares',
  'Create post': 'Crear publicación',
  'What would you like to share?': '¿Qué te gustaría compartir?',
  'Photo': 'Foto',
  'Video': 'Vídeo',
  'Publish': 'Publicar',
  'Bring your community together': 'Reúne a tu comunidad',
  'Create an organized place for local news, jobs, events and conversations.':
      'Crea un espacio organizado para noticias, empleos, eventos y conversaciones locales.',
  'Create a community': 'Crear una comunidad',
  'Needs your attention': 'Requiere tu atención',
  'Posts awaiting approval': 'Publicaciones pendientes de aprobación',
  'Reports': 'Denuncias',
  'Membership requests': 'Solicitudes de ingreso',
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
  'Enter community': 'Entrar en la comunidad',
};
