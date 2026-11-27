# Komuna

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Komuna en dos dispositivos Android

1. Ejecuta la app en Android Studio o con `flutter run`. Android usa el
   proyecto Komuna y oculta el panel de pruebas de forma predeterminada.
2. Si necesitas un instalador, compila el APK con este comando.

   ```powershell
   flutter build apk --release
   ```

3. Instala ese APK en dos teléfonos. Registra una cuenta en cada uno y confirma
   ambos correos si el proyecto lo requiere. Publica un artículo con foto en
   uno, solicítalo desde el otro, acepta la solicitud, coordina por chat y
   confirma la entrega. Vuelve a abrir ambas apps para comprobar que conservan
   la sesión y muestran el mismo estado.

El piloto en línea incluye el acceso con correo, las publicaciones, las
propuestas, el chat, la entrega y las reseñas. Tras confirmar la recepción,
cada participante puede reseñar a la otra persona. Las reseñas recibidas
aparecen en **Perfil**. Carga las notificaciones y los demás cambios del
servidor cada cuatro segundos mientras la app está en uso. En Android, el
cálculo de distancias usa la colonia o el código postal de cada publicación y
la ubicación autorizada del dispositivo o la zona del perfil.

Para usar otro proyecto, aplica las migraciones de [donaciones](supabase/migrations/202611250001_donaplus.sql)
y [reseñas](supabase/migrations/20261126163026_komuna_donation_reviews.sql),
seguidas por las de [notificaciones](supabase/migrations/20261126185835_komuna_notifications.sql)
y [categoría Tecnología](supabase/migrations/20261126200056_komuna_technology_category.sql),
y pasa `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` con `--dart-define`. Configura
el correo de verificación del proyecto antes de abrir el registro al público.
