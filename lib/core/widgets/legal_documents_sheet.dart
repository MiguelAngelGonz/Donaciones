import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/location/android_device_location.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator_android/geolocator_android.dart';

/// Available tabs in the Komuna legal documents bottom sheet.
enum LegalDocumentTab { privacy, terms }

/// Opens the reusable modal bottom sheet with the Privacy Notice and Terms of Use.
Future<void> showLegalDocumentsSheet(
  BuildContext context, {
  LegalDocumentTab initialTab = LegalDocumentTab.privacy,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LegalDocumentsSheet(initialTab: initialTab),
  );
}

/// Modal bottom sheet displaying the full Komuna Privacy Notice and Terms of Use.
class LegalDocumentsSheet extends StatefulWidget {
  final LegalDocumentTab initialTab;

  const LegalDocumentsSheet({
    super.key,
    this.initialTab = LegalDocumentTab.privacy,
  });

  @override
  State<LegalDocumentsSheet> createState() => _LegalDocumentsSheetState();
}

class _LegalDocumentsSheetState extends State<LegalDocumentsSheet> {
  late LegalDocumentTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aviso de Privacidad y Términos',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('legal_tab_privacy'),
                    avatar: const Icon(Icons.privacy_tip_outlined, size: 16),
                    label: const Text('Aviso de Privacidad'),
                    selected: _selectedTab == LegalDocumentTab.privacy,
                    onSelected: (_) =>
                        setState(() => _selectedTab = LegalDocumentTab.privacy),
                  ),
                  ChoiceChip(
                    key: const Key('legal_tab_terms'),
                    avatar: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Términos y Condiciones'),
                    selected: _selectedTab == LegalDocumentTab.terms,
                    onSelected: (_) =>
                        setState(() => _selectedTab = LegalDocumentTab.terms),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: highContrast
                        ? Colors.white
                        : DonaPlusColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: highContrast
                          ? Colors.black
                          : theme.colorScheme.outline,
                      width: highContrast ? 1.5 : 1.0,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: _selectedTab == LegalDocumentTab.privacy
                        ? const _PrivacyNoticeContent()
                        : const _TermsAndConditionsContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNoticeContent extends StatelessWidget {
  const _PrivacyNoticeContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalClause(
          title: '1. Minimización de datos (RNF-09)',
          body: 'Komuna solicita únicamente los datos indispensables para identificar a los miembros de la comunidad y coordinar donaciones solidarias. Nunca solicitamos ni publicamos tu domicilio exacto.',
        ),
        SizedBox(height: 12),
        _LegalClause(
          title: '2. Ubicación aproximada y permiso del dispositivo (RNF-08 / CU-21)',
          body: 'Las publicaciones utilizan solo colonia o código postal para estimar cercanía en kilómetros. La ubicación del dispositivo nunca se consulta sin tu autorización explícita previa y puedes revocarla en cualquier momento desde el feed o desde tu perfil.',
        ),
        SizedBox(height: 12),
        _LegalClause(
          title: '3. Privacidad de teléfono y beneficiarios (CU-31 / CU-47)',
          body: 'Tu número telefónico permanece oculto en las conversaciones de coordinación a menos que actives explícitamente la opción de compartirlo en una donación activa. Cuando un intermediario comunitario publica en nombre de un beneficiario, solo se registra un alias público sin exponer sus datos personales.',
        ),
        SizedBox(height: 12),
        _LegalClause(
          title: '4. Seguridad de credenciales y cámara/galería (RNF-07)',
          body: 'Tu contraseña se resguarda mediante resumen criptográfico y jamás se almacena en texto plano. El acceso a cámara o galería solo se emplea cuando decides adjuntar fotografías a tu perfil, artículos, ofertas o documentos de respaldo.',
        ),
      ],
    );
  }
}

class _TermsAndConditionsContent extends StatelessWidget {
  const _TermsAndConditionsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalClause(
          title: '1. Gratuidad obligatoria y prohibición de venta',
          body: 'Toda publicación, solicitud y oferta dentro de Komuna es estrictamente gratuita y solidaria. Queda prohibido exigir pagos en efectivo, transferencias, cobros ocultos o condicionamientos comerciales a cambio de un artículo.',
        ),
        SizedBox(height: 12),
        _LegalClause(
          title: '2. Artículos permitidos y reglas de Alimentación',
          body: 'Los artículos ofrecidos deben encontrarse en condiciones seguras e higiénicas. En la categoría de Alimentación solo se permiten alimentos en envases cerrados (latas, botellas, sobres u otra presentación sellada), especificando su presentación y respetando su fecha de caducidad vigente.',
        ),
        SizedBox(height: 12),
        _LegalClause(
          title:
              '3. Coordinación, entregas seguras y cierre a los 7 días (CU-34)',
          body: 'Donante y donatario acuerdan libremente un punto público y horario seguro para la entrega. Una vez que el donante marca la donación como Entregada, el donatario cuenta con 7 días para confirmar la recepción; transcurrido ese plazo, el Sistema finaliza la donación automáticamente y habilita la ventana de 14 días para reseñas verificadas (CU-37).',
        ),
        SizedBox(height: 12),
        _LegalClause(
          title: '4. Rol de intermediario comunitario (CU-40 a CU-47)',
          body: 'Los intermediarios autorizados por la administración se comprometen a representar fielmente a personas con acceso digital limitado, adjuntar documentación de respaldo verídica y entregar íntegramente las donaciones recibidas a los beneficiarios representados.',
        ),
      ],
    );
  }
}

class _LegalClause extends StatelessWidget {
  final String title;
  final String body;

  const _LegalClause({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Card shown in ProfileScreen to manage device permissions and read legal documents.
class LegalAndPermissionsCard extends ConsumerStatefulWidget {
  const LegalAndPermissionsCard({super.key});

  @override
  ConsumerState<LegalAndPermissionsCard> createState() =>
      _LegalAndPermissionsCardState();
}

class _LegalAndPermissionsCardState
    extends ConsumerState<LegalAndPermissionsCard> {
  bool _requestingLocation = false;

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _handleLocationToggle(MockTenantStore store) async {
    if (_requestingLocation) return;
    if (store.isDeviceLocationAuthorized) {
      store.setDeviceLocationAuthorized(false);
      return;
    }

    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Autorizar ubicación del dispositivo'),
        content: const Text(
          '¿Permites que Komuna use la ubicación aproximada de tu dispositivo '
          'para mostrar el código postal y calcular distancias?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Denegar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );

    if (!mounted || allowed == null || _requestingLocation) return;
    if (!allowed) {
      _showMessage(
        'Permiso denegado. Se utilizará la ubicación aproximada registrada en tu perfil.',
      );
      return;
    }
    if (!usesAndroidDeviceAccess) {
      store.setDeviceLocationAuthorized(true);
      return;
    }

    setState(() => _requestingLocation = true);
    try {
      final locator = GeolocatorAndroid();
      var permission = await locator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Puedes habilitar el permiso de ubicación de Komuna en los ajustes de Android.',
          action: SnackBarAction(
            label: 'Ajustes',
            onPressed: () => locator.openAppSettings(),
          ),
        );
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showMessage(
          'Permiso denegado. Se utilizará la ubicación aproximada registrada en tu perfil.',
        );
        return;
      }
      final location = await readAndroidDeviceLocation(locator);
      if (!mounted) return;
      store.setDeviceLocationAuthorized(true, location: location);
    } on LocationServiceDisabledException {
      if (mounted) {
        _showMessage(
          'Activa la ubicación en Android para calcular las distancias con tu dispositivo.',
        );
      }
    } on Exception {
      if (mounted) {
        _showMessage(
          'No se pudo obtener la ubicación. Se utilizará la ubicación aproximada de tu perfil.',
        );
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Privacidad, Términos y Permisos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('profile_device_location_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ubicación aproximada del dispositivo (CU-21 / RNF-08)',
              ),
              subtitle: Text(
                store.isDeviceLocationAuthorized
                    ? 'Autorizada para mostrar el código postal y calcular distancias.'
                    : 'Desactivada (se usa la colonia o CP de tu perfil).',
              ),
              value: store.isDeviceLocationAuthorized,
              onChanged:
                  _requestingLocation ||
                      (store.isOnline && !usesAndroidDeviceAccess)
                  ? null
                  : (_) => _handleLocationToggle(store),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.camera_alt_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Cámara y Galería del dispositivo'),
              subtitle: const Text(
                'Se solicita únicamente al tomar o elegir fotografías en perfil, artículos, ofertas o documentos de respaldo.',
              ),
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('open_privacy_notice_button'),
                  onPressed: () => showLegalDocumentsSheet(
                    context,
                    initialTab: LegalDocumentTab.privacy,
                  ),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('Aviso de Privacidad'),
                ),
                OutlinedButton.icon(
                  key: const Key('open_terms_conditions_button'),
                  onPressed: () => showLegalDocumentsSheet(
                    context,
                    initialTab: LegalDocumentTab.terms,
                  ),
                  icon: const Icon(Icons.gavel_outlined, size: 18),
                  label: const Text('Términos y Condiciones'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
