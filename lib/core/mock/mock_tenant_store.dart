import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart' as sb;

part 'online_tenant_store.dart';

/// Reactive Riverpod provider exposing the shared in-memory [MockTenantStore].
final mockTenantStoreProvider = ChangeNotifierProvider<MockTenantStore>(
  (ref) => MockTenantStore(),
);

class _TrustBaseline {
  final int finalizedDonations;
  final int reviewCount;
  final double ratingSum;

  const _TrustBaseline({
    this.finalizedDonations = 0,
    this.reviewCount = 0,
    this.ratingSum = 0.0,
  });
}

/// Self-contained in-memory tenant store covering all 51 use cases (CU-01..CU-51).
class MockTenantStore extends ChangeNotifier {
  static const int _maxDocumentBytes = 5 * 1024 * 1024;
  static const List<String> _allowedDocumentExtensions = [
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
  ];
  static const List<String> _sampleItemPhotos = [
    'sample://silla_ruedas.jpg',
    'sample://mesa_comedor.jpg',
    'sample://chaqueta_invierno.jpg',
    'sample://libros_primaria.jpg',
    'sample://cobijas_termicas.jpg',
  ];
  static const UbicacionMock _simulatedDeviceLocation = UbicacionMock(
    etiqueta: 'Ubicación del dispositivo',
    distanciaKmSimulada: 0.0,
    latitud: 19.0435,
    longitud: -98.2070,
  );
  static final DateTime _seedReferenceTime = DateTime(2026, 11, 18, 12, 0);

  final List<UsuarioMock> _users = [];
  final List<CuentaAccesoMock> _accounts = [];
  final List<CategoriaMock> _categories = [];
  final List<PublicacionMock> _publications = [];
  final List<PropuestaMock> _proposals = [];
  final List<DonacionMock> _donations = [];
  final List<ResenaMock> _reviews = [];
  final List<SolicitudRolIntermediarioMock> _intermediaryRequests = [];
  final List<NotificacionMock> _notifications = [];
  final List<TokenRestablecimientoMock> _resetTokens = [];
  final Map<String, String> _donationClientKeys = {};
  final Map<String, _TrustBaseline> _seedTrustBaselines = {};

  String? _activeUserId;
  bool _simulateNetworkError = false;
  UbicacionMock? _deviceLocation;
  late DateTime _currentTime;

  int _userSeq = 0;
  int _catSeq = 0;
  int _pubSeq = 0;
  int _propSeq = 0;
  int _donSeq = 0;
  int _msgSeq = 0;
  int _revSeq = 0;
  int _rolSeq = 0;
  int _notifSeq = 0;
  int _tokenSeq = 0;

  MockTenantStore({bool seed = true}) {
    if (seed) {
      resetToSeed();
    } else {
      _currentTime = DateTime.now();
    }
  }

  bool get isOnline => false;

  String sharedPhoneFor(String donationId, UsuarioMock counterpart) =>
      counterpart.telefono;

  // ---------------------------------------------------------------------------
  // Read-only collection getters
  // ---------------------------------------------------------------------------

  List<UsuarioMock> get users => List.unmodifiable(_users);
  List<CuentaAccesoMock> get accounts => List.unmodifiable(_accounts);
  List<CategoriaMock> get categories => List.unmodifiable(_categories);
  List<PublicacionMock> get publications => List.unmodifiable(_publications);
  List<PropuestaMock> get proposals => List.unmodifiable(_proposals);
  List<DonacionMock> get donations => List.unmodifiable(_donations);
  List<ResenaMock> get reviews => List.unmodifiable(_reviews);
  List<SolicitudRolIntermediarioMock> get intermediaryRequests =>
      List.unmodifiable(_intermediaryRequests);
  List<NotificacionMock> get notifications => List.unmodifiable(_notifications);
  List<TokenRestablecimientoMock> get resetTokens =>
      List.unmodifiable(_resetTokens);

  // ---------------------------------------------------------------------------
  // Tenant control, active session, and simulated clock
  // ---------------------------------------------------------------------------

  bool get simulateNetworkError => _simulateNetworkError;

  void setSimulateNetworkError(bool value) {
    _simulateNetworkError = value;
    notifyListeners();
  }

  UsuarioMock? get activeUser =>
      _activeUserId == null ? null : findUserById(_activeUserId!);

  void setActiveUser(String? userId) {
    if (userId != null && findUserById(userId) == null) {
      throw const ValidationException('Usuario de prueba no encontrado.');
    }
    _activeUserId = userId;
    notifyListeners();
  }

  DateTime get currentTime => _currentTime;

  /// Advances the simulated clock and runs automatic donation finalization (CU-34 2a).
  void advanceClock(Duration delta) {
    _currentTime = _currentTime.add(delta);
    runAutomaticFinalizationCheck();
    notifyListeners();
  }

  bool get isDeviceLocationAuthorized => _deviceLocation != null;
  String? get devicePostalCode => _deviceLocation?.codigoPostal;

  void setDeviceLocationAuthorized(bool authorized, {UbicacionMock? location}) {
    _deviceLocation = authorized ? location ?? _simulatedDeviceLocation : null;
    notifyListeners();
  }

  UsuarioMock? findUserById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  CuentaAccesoMock? findAccountByUserId(String userId) {
    for (final account in _accounts) {
      if (account.usuarioId == userId) return account;
    }
    return null;
  }

  CategoriaMock? findCategoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  PublicacionMock? findPublicationById(String id) {
    for (final publication in _publications) {
      if (publication.id == id) return publication;
    }
    return null;
  }

  DonacionMock? findDonationById(String id) {
    for (final donation in _donations) {
      if (donation.id == id) return donation;
    }
    return null;
  }

  /// Restores the store to the deterministic initial seed state.
  void resetToSeed() {
    _users.clear();
    _accounts.clear();
    _categories.clear();
    _publications.clear();
    _proposals.clear();
    _donations.clear();
    _reviews.clear();
    _intermediaryRequests.clear();
    _notifications.clear();
    _resetTokens.clear();
    _donationClientKeys.clear();
    _seedTrustBaselines.clear();

    _currentTime = _seedReferenceTime;
    _activeUserId = 'usr-alondra';
    _simulateNetworkError = false;
    _deviceLocation = null;

    _userSeq = 3;
    _catSeq = 6;
    _pubSeq = 4;
    _propSeq = 1;
    _donSeq = 1;
    _msgSeq = 1;
    _revSeq = 3;
    _rolSeq = 1;
    _notifSeq = 0;
    _tokenSeq = 0;

    final seedPasswordHash = _hashPassword('DonaPlus1');

    _users.addAll([
      UsuarioMock(
        id: 'usr-alondra',
        nombreUsuario: 'alondra.dona',
        nombreLegal: 'Guadalupe Alondra Gutiérrez Paz',
        correo: 'alondra.demo@donaplus.app',
        telefono: '2221234457',
        ubicacionAproximada: const UbicacionMock(
          etiqueta: 'Col. Centro, CP 72000',
          distanciaKmSimulada: 0.8,
          latitud: 19.0414,
          longitud: -98.2063,
        ),
        avisoPrivacidadAceptado: true,
        correoVerificado: true,
        perfilConfianzaOtorgado: true,
        promedioCalificacion: 4.8,
        donacionesFinalizadas: 12,
        numeroResenas: 10,
        esAdministrador: true,
        esIntermediario: false,
        fechaRegistro: _seedReferenceTime.subtract(const Duration(days: 90)),
      ),
      UsuarioMock(
        id: 'usr-maria',
        nombreUsuario: 'maria.lopez',
        nombreLegal: 'María López Hernández',
        correo: 'maria@donaplus.app',
        telefono: '2229876543',
        ubicacionAproximada: const UbicacionMock(
          etiqueta: 'Col. La Paz, CP 72160',
          distanciaKmSimulada: 2.4,
          latitud: 19.0630,
          longitud: -98.2063,
        ),
        avisoPrivacidadAceptado: true,
        correoVerificado: true,
        perfilConfianzaOtorgado: true,
        promedioCalificacion: 4.8,
        donacionesFinalizadas: 6,
        numeroResenas: 5,
        esAdministrador: false,
        esIntermediario: true,
        fechaRegistro: _seedReferenceTime.subtract(const Duration(days: 60)),
      ),
      UsuarioMock(
        id: 'usr-diego',
        nombreUsuario: 'diego.solidario',
        nombreLegal: 'Diego Ramírez Soto',
        correo: 'diego@donaplus.app',
        telefono: '2225550199',
        ubicacionAproximada: const UbicacionMock(
          etiqueta: 'Col. San Manuel, CP 72570',
          distanciaKmSimulada: 3.1,
          latitud: 19.0135,
          longitud: -98.2063,
        ),
        avisoPrivacidadAceptado: true,
        correoVerificado: true,
        perfilConfianzaOtorgado: false,
        promedioCalificacion: 4.2,
        donacionesFinalizadas: 2,
        numeroResenas: 2,
        esAdministrador: false,
        esIntermediario: false,
        fechaRegistro: _seedReferenceTime.subtract(const Duration(days: 30)),
      ),
    ]);

    for (final user in _users) {
      _accounts.add(
        CuentaAccesoMock(
          usuarioId: user.id,
          passwordHash: seedPasswordHash,
          correoVerificado: true,
        ),
      );
    }

    // Historical trust baselines keep seed totals consistent with live recalculation.
    _seedTrustBaselines['usr-alondra'] = const _TrustBaseline(
      finalizedDonations: 11,
      reviewCount: 8,
      ratingSum: 38.0,
    );
    _seedTrustBaselines['usr-maria'] = const _TrustBaseline(
      finalizedDonations: 6,
      reviewCount: 4,
      ratingSum: 19.0,
    );
    _seedTrustBaselines['usr-diego'] = const _TrustBaseline(
      finalizedDonations: 1,
      reviewCount: 2,
      ratingSum: 8.4,
    );

    _categories.addAll(const [
      CategoriaMock(
        id: 'cat-salud',
        nombre: 'Salud',
        iconoClave: 'health',
        activa: true,
      ),
      CategoriaMock(
        id: 'cat-educacion',
        nombre: 'Educación',
        iconoClave: 'school',
        activa: true,
      ),
      CategoriaMock(
        id: CategoriaMock.alimentacionId,
        nombre: 'Alimentación',
        iconoClave: 'restaurant',
        activa: true,
      ),
      CategoriaMock(
        id: 'cat-ropa',
        nombre: 'Ropa',
        iconoClave: 'checkroom',
        activa: true,
      ),
      CategoriaMock(
        id: 'cat-hogar',
        nombre: 'Artículos para el hogar',
        iconoClave: 'chair',
        activa: true,
      ),
      CategoriaMock(
        id: 'cat-tecnologia',
        nombre: 'Tecnología',
        iconoClave: 'devices',
        activa: true,
      ),
      CategoriaMock(
        id: 'cat-inactiva',
        nombre: 'Electrónica antigua',
        iconoClave: 'devices',
        activa: false,
      ),
    ]);

    _publications.addAll([
      PublicacionMock(
        id: 'pub-1',
        tipo: TipoPublicacion.necesidad,
        autorId: 'usr-maria',
        categoriaId: 'cat-salud',
        titulo: 'Silla de ruedas plegable',
        descripcion: 'Silla de ruedas en buen estado disponible para una persona adulta que la necesite.',
        estado: EstadoPublicacion.activa,
        ubicacion: const UbicacionMock(
          etiqueta: 'Col. La Paz, CP 72160',
          distanciaKmSimulada: 2.4,
          latitud: 19.0630,
          longitud: -98.2063,
        ),
        fechaPublicacion: _seedReferenceTime.subtract(const Duration(days: 3)),
        cantidad: 1,
        condicion: CondicionArticulo.usado,
        urgencia: Urgencia.alta,
        caracteristicas: const {'Tipo': 'Plegable adulto'},
      ),
      PublicacionMock(
        id: 'pub-2',
        tipo: TipoPublicacion.necesidad,
        autorId: 'usr-diego',
        categoriaId: 'cat-educacion',
        titulo: 'Libros escolares de primaria',
        descripcion: 'Se necesitan libros de texto y cuadernos para alumnos de primaria.',
        estado: EstadoPublicacion.activa,
        ubicacion: const UbicacionMock(
          etiqueta: 'Col. San Manuel, CP 72570',
          distanciaKmSimulada: 3.1,
          latitud: 19.0135,
          longitud: -98.2063,
        ),
        fechaPublicacion: _seedReferenceTime.subtract(const Duration(days: 2)),
        cantidad: 5,
        urgencia: Urgencia.media,
        caracteristicas: const {'Grado': '3ro y 4to'},
      ),
      PublicacionMock(
        id: 'pub-3',
        tipo: TipoPublicacion.articulo,
        autorId: 'usr-maria',
        categoriaId: 'cat-hogar',
        titulo: 'Mesa de comedor para 4 personas',
        descripcion: 'Mesa de madera firme y cuidada, ideal para departamento o casa pequeña.',
        estado: EstadoPublicacion.activa,
        ubicacion: const UbicacionMock(
          etiqueta: 'Col. La Paz, CP 72160',
          distanciaKmSimulada: 1.1,
          latitud: 19.0513,
          longitud: -98.2063,
        ),
        fechaPublicacion: _seedReferenceTime.subtract(const Duration(days: 1)),
        cantidad: 1,
        condicion: CondicionArticulo.comoNuevo,
        fotografias: const [
          'sample://mesa_comedor_1.jpg',
          'sample://mesa_comedor_2.jpg',
        ],
      ),
      PublicacionMock(
        id: 'pub-4',
        tipo: TipoPublicacion.articulo,
        autorId: 'usr-diego',
        categoriaId: 'cat-ropa',
        titulo: 'Chaqueta de invierno talla M',
        descripcion: 'Chaqueta térmica nueva con cierre completo y gorro.',
        estado: EstadoPublicacion.activa,
        ubicacion: const UbicacionMock(
          etiqueta: 'Col. San Manuel, CP 72570',
          distanciaKmSimulada: 1.3,
          latitud: 19.0297,
          longitud: -98.2063,
        ),
        fechaPublicacion: _seedReferenceTime.subtract(
          const Duration(hours: 12),
        ),
        cantidad: 1,
        condicion: CondicionArticulo.nuevo,
        fotografias: const ['sample://chaqueta_invierno_1.jpg'],
      ),
      PublicacionMock(
        id: 'pub-hist-1',
        tipo: TipoPublicacion.articulo,
        autorId: 'usr-alondra',
        categoriaId: 'cat-educacion',
        titulo: 'Mochila escolar reforzada',
        descripcion: 'Mochila amplia con compartimentos para útiles escolares.',
        estado: EstadoPublicacion.cerrada,
        ubicacion: const UbicacionMock(
          etiqueta: 'Col. Centro, CP 72000',
          distanciaKmSimulada: 0.8,
          latitud: 19.0414,
          longitud: -98.2063,
        ),
        fechaPublicacion: _seedReferenceTime.subtract(const Duration(days: 18)),
        cantidad: 1,
        condicion: CondicionArticulo.comoNuevo,
        fotografias: const ['sample://mochila_escolar_1.jpg'],
      ),
    ]);

    _donations.add(
      DonacionMock(
        id: 'don-hist-1',
        publicacionId: 'pub-hist-1',
        propuestaId: 'prop-hist-1',
        donanteId: 'usr-alondra',
        donatarioId: 'usr-diego',
        estado: EstadoDonacion.finalizada,
        lugarEntrega: 'Parque del Carmen, Puebla',
        fechaEntregaAcordada: _seedReferenceTime.subtract(
          const Duration(days: 12),
        ),
        fechaEntregada: _seedReferenceTime.subtract(const Duration(days: 12)),
        fechaFinalizacion: _seedReferenceTime.subtract(
          const Duration(days: 10),
        ),
        historialCambios: List.unmodifiable([
          CambioEstadoMock(
            estadoAnterior: null,
            estadoNuevo: EstadoDonacion.aceptada,
            fechaHora: _seedReferenceTime.subtract(const Duration(days: 14)),
            actorId: 'usr-alondra',
            nota: 'Solicitud aceptada',
          ),
          CambioEstadoMock(
            estadoAnterior: EstadoDonacion.aceptada,
            estadoNuevo: EstadoDonacion.enEntrega,
            fechaHora: _seedReferenceTime.subtract(const Duration(days: 13)),
            actorId: 'usr-alondra',
            nota: 'Lugar y fecha acordados: Parque del Carmen, Puebla',
          ),
          CambioEstadoMock(
            estadoAnterior: EstadoDonacion.enEntrega,
            estadoNuevo: EstadoDonacion.entregada,
            fechaHora: _seedReferenceTime.subtract(const Duration(days: 12)),
            actorId: 'usr-alondra',
            nota: 'Entrega marcada por el donante',
          ),
          CambioEstadoMock(
            estadoAnterior: EstadoDonacion.entregada,
            estadoNuevo: EstadoDonacion.finalizada,
            fechaHora: _seedReferenceTime.subtract(const Duration(days: 10)),
            actorId: 'usr-diego',
            nota: 'Recepción confirmada por el donatario',
          ),
        ]),
        mensajes: List.unmodifiable([
          MensajeMock(
            id: 'msg-hist-1',
            donacionId: 'don-hist-1',
            remitenteId: 'usr-diego',
            contenido: '¡Muchas gracias por la mochila, ya la recibimos!',
            fechaHora: _seedReferenceTime.subtract(const Duration(days: 10)),
          ),
        ]),
      ),
    );

    _reviews.addAll([
      ResenaMock(
        id: 'rev-seed-1',
        donacionId: 'don-hist-prev-1',
        autorId: 'usr-maria',
        resenadoId: 'usr-alondra',
        calificacion: 5,
        comentario: 'Excelente coordinación y trato muy amable.',
        fecha: _seedReferenceTime.subtract(const Duration(days: 20)),
      ),
      ResenaMock(
        id: 'rev-seed-2',
        donacionId: 'don-hist-1',
        autorId: 'usr-diego',
        resenadoId: 'usr-alondra',
        calificacion: 5,
        comentario: 'Mochila en perfecto estado y entrega puntual.',
        fecha: _seedReferenceTime.subtract(const Duration(days: 9)),
      ),
      ResenaMock(
        id: 'rev-seed-3',
        donacionId: 'don-hist-prev-2',
        autorId: 'usr-alondra',
        resenadoId: 'usr-maria',
        calificacion: 5,
        comentario: 'Donante muy comprometida con la comunidad.',
        fecha: _seedReferenceTime.subtract(const Duration(days: 15)),
      ),
    ]);

    _intermediaryRequests.add(
      SolicitudRolIntermediarioMock(
        id: 'rol-seed-maria',
        usuarioId: 'usr-maria',
        organizacion: 'Fundación Apoyo Comunitario Puebla',
        documentoNombre: 'acta_fundacion_puebla.pdf',
        documentoBytesSimulados: 512 * 1024,
        estado: EstadoSolicitudRol.aprobada,
        fechaSolicitud: _seedReferenceTime.subtract(const Duration(days: 30)),
        fechaDecision: _seedReferenceTime.subtract(const Duration(days: 28)),
        revisadaPorAdminId: 'usr-alondra',
        motivoDecision: 'Documentación verificada',
      ),
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bloque 1: Auth, Perfil y Confianza (CU-01 a CU-10)
  // ---------------------------------------------------------------------------

  bool isUsernameTaken(String username) {
    final normalized = _normalizeUsername(username);
    if (normalized.isEmpty) return false;
    return _users.any((u) => _normalizeUsername(u.nombreUsuario) == normalized);
  }

  bool isEmailTaken(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _users.any((u) => u.correo.trim().toLowerCase() == normalized);
  }

  Future<UsuarioMock> registerUser(RegisterUserInput input) async {
    _ensureNetworkAvailable();

    final cleanUsername = _stripLeadingAt(input.nombreUsuario.trim());
    if (isUsernameTaken(cleanUsername)) {
      throw const DuplicateUsernameException();
    }
    if (cleanUsername.isEmpty || cleanUsername.contains(RegExp(r'\s'))) {
      throw const ValidationException('Ingresa un nombre de usuario válido.');
    }
    if (input.nombreLegal.trim().isEmpty) {
      throw const ValidationException(
        'El nombre legal completo es obligatorio.',
      );
    }

    final cleanEmail = input.correo.trim();
    if (!_isValidEmail(cleanEmail)) {
      throw const ValidationException('Ingresa un correo electrónico válido.');
    }
    if (isEmailTaken(cleanEmail)) {
      throw const ValidationException(
        'El correo electrónico ya está registrado.',
      );
    }

    final cleanPhone = input.telefono.trim();
    _validatePhone(cleanPhone);
    _validatePassword(input.password);

    final cleanLocation = input.ubicacionEtiqueta.trim();
    if (cleanLocation.isEmpty) {
      throw const ValidationException(
        'La ubicación aproximada (colonia o código postal) es obligatoria.',
      );
    }
    if (!input.avisoPrivacidadAceptado) {
      throw const ValidationException(
        'Debes aceptar el aviso de privacidad para completar el registro.',
      );
    }

    final user = UsuarioMock(
      id: 'usr-${++_userSeq}',
      nombreUsuario: cleanUsername,
      nombreLegal: input.nombreLegal.trim(),
      correo: cleanEmail,
      telefono: cleanPhone,
      fotoPerfil: input.fotoPerfil,
      ubicacionAproximada: _buildLocation(cleanLocation),
      avisoPrivacidadAceptado: true,
      correoVerificado: false,
      perfilConfianzaOtorgado: false,
      promedioCalificacion: 0.0,
      donacionesFinalizadas: 0,
      numeroResenas: 0,
      fechaRegistro: _currentTime,
    );

    final account = CuentaAccesoMock(
      usuarioId: user.id,
      passwordHash: _hashPassword(input.password),
      correoVerificado: false,
    );

    _users.add(user);
    _accounts.add(account);
    notifyListeners();
    return user;
  }

  Future<void> verifyEmailForTest(String userId) async {
    _ensureNetworkAvailable();

    final userIdx = _users.indexWhere((u) => u.id == userId);
    final accIdx = _accounts.indexWhere((a) => a.usuarioId == userId);
    if (userIdx == -1 || accIdx == -1) {
      throw const ValidationException('Usuario no encontrado.');
    }

    _users[userIdx] = _users[userIdx].copyWith(correoVerificado: true);
    _accounts[accIdx] = _accounts[accIdx].copyWith(correoVerificado: true);
    notifyListeners();
  }

  Future<UsuarioMock> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    _ensureNetworkAvailable();

    final query = usernameOrEmail.trim();
    if (query.isEmpty || password.isEmpty) {
      throw const ValidationException(
        'Ingresa tu usuario o correo y contraseña.',
      );
    }

    final normalizedQuery = query.toLowerCase();
    final normalizedUserQuery = _normalizeUsername(query);

    final userIdx = _users.indexWhere(
      (u) =>
          u.correo.trim().toLowerCase() == normalizedQuery ||
          _normalizeUsername(u.nombreUsuario) == normalizedUserQuery,
    );
    if (userIdx == -1) {
      throw const InvalidCredentialsException();
    }

    final user = _users[userIdx];
    final accIdx = _accounts.indexWhere((a) => a.usuarioId == user.id);
    var account = _accounts[accIdx];

    if (account.bloqueadaHasta != null) {
      if (_currentTime.isBefore(account.bloqueadaHasta!)) {
        throw const AccountLockedException();
      }
      account = account.copyWith(
        intentosFallidos: 0,
        clearBloqueadaHasta: true,
      );
      _accounts[accIdx] = account;
    }

    if (_hashPassword(password) != account.passwordHash) {
      final attempts = account.intentosFallidos + 1;
      if (attempts >= 5) {
        _accounts[accIdx] = account.copyWith(
          intentosFallidos: attempts,
          bloqueadaHasta: _currentTime.add(const Duration(minutes: 15)),
        );
        notifyListeners();
        throw const AccountLockedException();
      }
      _accounts[accIdx] = account.copyWith(intentosFallidos: attempts);
      notifyListeners();
      throw const InvalidCredentialsException();
    }

    if (!account.correoVerificado || !user.correoVerificado) {
      throw const UnverifiedEmailException();
    }

    _accounts[accIdx] = account.copyWith(
      intentosFallidos: 0,
      clearBloqueadaHasta: true,
    );
    _activeUserId = user.id;
    notifyListeners();
    return user;
  }

  Future<TokenRestablecimientoMock> requestPasswordReset(String email) async {
    _ensureNetworkAvailable();

    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      throw const ValidationException('Ingresa un correo electrónico válido.');
    }

    final userIdx = _users.indexWhere(
      (u) => u.correo.trim().toLowerCase() == normalized,
    );
    if (userIdx == -1) {
      throw const ValidationException(
        'No existe una cuenta registrada con ese correo electrónico.',
      );
    }

    final user = _users[userIdx];
    final token = TokenRestablecimientoMock(
      token: 'rst-${++_tokenSeq}-${user.id}',
      usuarioId: user.id,
      correo: user.correo,
      expiraEn: _currentTime.add(const Duration(minutes: 30)),
    );
    _resetTokens.add(token);
    notifyListeners();
    return token;
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    _ensureNetworkAvailable();

    final cleanToken = token.trim();
    final tokenIdx = _resetTokens.indexWhere((t) => t.token == cleanToken);
    if (tokenIdx == -1) {
      throw const ExpiredOrUsedTokenException();
    }

    final resetToken = _resetTokens[tokenIdx];
    if (resetToken.usado || !_currentTime.isBefore(resetToken.expiraEn)) {
      throw const ExpiredOrUsedTokenException();
    }

    _validatePassword(newPassword);

    final accIdx = _accounts.indexWhere(
      (a) => a.usuarioId == resetToken.usuarioId,
    );
    if (accIdx == -1) {
      throw const ValidationException('Cuenta asociada no encontrada.');
    }

    _accounts[accIdx] = _accounts[accIdx].copyWith(
      passwordHash: _hashPassword(newPassword),
      intentosFallidos: 0,
      clearBloqueadaHasta: true,
    );
    _resetTokens[tokenIdx] = resetToken.copyWith(usado: true);
    notifyListeners();
  }

  void logout() {
    _activeUserId = null;
    notifyListeners();
  }

  Future<UsuarioMock> updateProfile({
    String? fotoPerfil,
    required String telefono,
    String? newPassword,
  }) async {
    _ensureNetworkAvailable();

    final current = _requireAuthenticatedUser(
      'Debes iniciar sesión para editar tu perfil.',
    );
    final cleanPhone = telefono.trim();
    _validatePhone(cleanPhone);

    if (newPassword != null && newPassword.isNotEmpty) {
      _validatePassword(newPassword);
      final accIdx = _accounts.indexWhere((a) => a.usuarioId == current.id);
      if (accIdx != -1) {
        _accounts[accIdx] = _accounts[accIdx].copyWith(
          passwordHash: _hashPassword(newPassword),
        );
      }
    }

    final userIdx = _users.indexWhere((u) => u.id == current.id);
    final clearPhoto = fotoPerfil != null && fotoPerfil.trim().isEmpty;
    final updated = current.copyWith(
      telefono: cleanPhone,
      fotoPerfil: clearPhoto ? null : fotoPerfil?.trim(),
      clearFotoPerfil: clearPhoto,
    );
    _users[userIdx] = updated;
    notifyListeners();
    return updated;
  }

  List<ResenaMock> getReviewsForUser(String userId) {
    final result = _reviews.where((r) => r.resenadoId == userId).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return List.unmodifiable(result);
  }

  void recalculateTrustProfile(String userId) {
    _recalculateTrustProfileInternal(userId);
    notifyListeners();
  }

  void _recalculateTrustProfileInternal(String userId) {
    final userIdx = _users.indexWhere((u) => u.id == userId);
    if (userIdx == -1) {
      throw const ValidationException('Usuario no encontrado.');
    }

    final base = _seedTrustBaselines[userId] ?? const _TrustBaseline();
    final liveFinalized = _donations
        .where(
          (d) =>
              d.estado == EstadoDonacion.finalizada &&
              (d.donanteId == userId || d.donatarioId == userId),
        )
        .length;

    final userReviews = _reviews.where((r) => r.resenadoId == userId).toList();
    final liveRatingSum = userReviews.fold<int>(
      0,
      (sum, r) => sum + r.calificacion,
    );

    final totalDonations = base.finalizedDonations + liveFinalized;
    final totalReviews = base.reviewCount + userReviews.length;
    final totalRatingSum = base.ratingSum + liveRatingSum;
    final rawAverage = totalReviews == 0 ? 0.0 : totalRatingSum / totalReviews;
    final roundedAverage = totalReviews == 0
        ? 0.0
        : double.parse(rawAverage.toStringAsFixed(2));
    final granted =
        totalDonations >= 5 && rawAverage >= 4.0 && totalReviews >= 3;

    _users[userIdx] = _users[userIdx].copyWith(
      donacionesFinalizadas: totalDonations,
      numeroResenas: totalReviews,
      promedioCalificacion: roundedAverage,
      perfilConfianzaOtorgado: granted,
    );
  }

  // ---------------------------------------------------------------------------
  // Bloque 2 y 3: Publicaciones, Cercanía, Urgencia y Coincidencias
  // ---------------------------------------------------------------------------

  List<CategoriaMock> getActiveCategories() {
    return List.unmodifiable(_categories.where((c) => c.activa));
  }

  List<CategoriaMock> getCategoriesForFilter() {
    return List.unmodifiable(_categories.where((c) => c.activa));
  }

  List<String> getSampleItemPhotos() {
    return List.unmodifiable(_sampleItemPhotos);
  }

  bool get canFilterByDistance => true;

  double? getDistanceForPublication(PublicacionMock publication) {
    final deviceLocation = _deviceLocation;
    if (deviceLocation != null) {
      return deviceLocation.distanceKmTo(publication.ubicacion);
    }
    final user = activeUser;
    if (user == null || user.id == 'usr-alondra') {
      return publication.ubicacion.distanciaKmSimulada;
    }
    return user.ubicacionAproximada.distanceKmTo(publication.ubicacion);
  }

  double? _distanceBetweenPublications(
    PublicacionMock first,
    PublicacionMock second,
  ) => first.ubicacion.distanceKmTo(second.ubicacion);

  Future<PublicacionMock> createNeedPublication(CreateNeedInput input) async {
    _ensureNetworkAvailable();
    final author = _requireAuthenticatedUser(
      'Debes iniciar sesión para publicar una necesidad.',
    );
    _validateNeedInput(input, author);

    final cleanDetails = input.detallesCaracteristicas.trim();
    final publication = PublicacionMock(
      id: 'pub-${++_pubSeq}',
      tipo: TipoPublicacion.necesidad,
      autorId: author.id,
      categoriaId: input.categoriaId,
      titulo: input.titulo.trim(),
      descripcion: input.descripcion.trim(),
      estado: EstadoPublicacion.activa,
      ubicacion: _buildLocation(input.ubicacionEtiqueta.trim()),
      fechaPublicacion: _currentTime,
      cantidad: input.cantidadRequerida,
      condicion: input.condicionAceptable,
      urgencia: input.urgencia,
      caracteristicas: cleanDetails.isEmpty
          ? const {}
          : Map.unmodifiable({'Detalles': cleanDetails}),
      gestionadaPorIntermediario: input.gestionadaPorIntermediario,
      aliasBeneficiario: input.gestionadaPorIntermediario
          ? input.aliasBeneficiario!.trim()
          : null,
    );

    _publications.add(publication);
    _generateMatchNotificationsForPublication(publication);
    notifyListeners();
    return publication;
  }

  Future<PublicacionMock> createItemPublication(CreateItemInput input) async {
    _ensureNetworkAvailable();
    final author = _requireAuthenticatedUser(
      'Debes iniciar sesión para publicar un artículo.',
    );
    _validateItemInput(input);

    final publication = PublicacionMock(
      id: 'pub-${++_pubSeq}',
      tipo: TipoPublicacion.articulo,
      autorId: author.id,
      categoriaId: input.categoriaId,
      titulo: input.titulo.trim(),
      descripcion: input.descripcion.trim(),
      estado: EstadoPublicacion.activa,
      ubicacion: _buildLocation(input.ubicacionEtiqueta.trim()),
      fechaPublicacion: _currentTime,
      cantidad: input.cantidad,
      condicion: input.condicion,
      caracteristicas: Map.unmodifiable(input.caracteristicas ?? const {}),
      fotografias: List.unmodifiable(input.fotografias),
    );

    _publications.add(publication);
    _generateMatchNotificationsForPublication(publication);
    notifyListeners();
    return publication;
  }

  Future<PublicacionMock> updateNeedPublication({
    required String publicationId,
    required CreateNeedInput input,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para editar una necesidad.',
    );
    final idx = _findEditablePublicationIndex(
      publicationId,
      actorId: actor.id,
      expectedType: TipoPublicacion.necesidad,
    );
    final existing = _publications[idx];

    _validateNeedInput(input, actor);
    final cleanDetails = input.detallesCaracteristicas.trim();
    final updated = existing.copyWith(
      categoriaId: input.categoriaId,
      titulo: input.titulo.trim(),
      descripcion: input.descripcion.trim(),
      ubicacion: _buildLocation(input.ubicacionEtiqueta.trim()),
      cantidad: input.cantidadRequerida,
      condicion: input.condicionAceptable,
      clearCondicion: input.condicionAceptable == null,
      urgencia: input.urgencia,
      caracteristicas: cleanDetails.isEmpty
          ? const {}
          : Map.unmodifiable({'Detalles': cleanDetails}),
      gestionadaPorIntermediario: input.gestionadaPorIntermediario,
      aliasBeneficiario: input.gestionadaPorIntermediario
          ? input.aliasBeneficiario!.trim()
          : null,
      clearAliasBeneficiario: !input.gestionadaPorIntermediario,
    );

    _publications[idx] = updated;
    _generateMatchNotificationsForPublication(updated);
    notifyListeners();
    return updated;
  }

  Future<PublicacionMock> updateItemPublication({
    required String publicationId,
    required CreateItemInput input,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para editar un artículo.',
    );
    final idx = _findEditablePublicationIndex(
      publicationId,
      actorId: actor.id,
      expectedType: TipoPublicacion.articulo,
    );
    final existing = _publications[idx];

    _validateItemInput(input);
    final saleDeAlimentacion =
        existing.categoriaId == CategoriaMock.alimentacionId &&
        input.categoriaId != existing.categoriaId;
    final updated = existing.copyWith(
      categoriaId: input.categoriaId,
      titulo: input.titulo.trim(),
      descripcion: input.descripcion.trim(),
      ubicacion: _buildLocation(input.ubicacionEtiqueta.trim()),
      cantidad: input.cantidad,
      condicion: input.condicion,
      clearCondicion: input.condicion == null,
      caracteristicas: Map.unmodifiable(
        input.caracteristicas ??
            (saleDeAlimentacion ? const {} : existing.caracteristicas),
      ),
      fotografias: List.unmodifiable(input.fotografias),
    );

    _publications[idx] = updated;
    _generateMatchNotificationsForPublication(updated);
    notifyListeners();
    return updated;
  }

  Future<void> withdrawPublication(String publicationId) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para retirar una publicación.',
    );
    final idx = _findEditablePublicationIndex(publicationId, actorId: actor.id);

    _withdrawPublicationAtIndex(
      idx,
      rejectionReason: 'La publicación fue retirada por su autor.',
    );
    notifyListeners();
  }

  List<PublicacionMock> filterActivePublications({
    String? categoryId,
    TipoPublicacion? type,
    Urgencia? urgency,
    bool sortByUrgency = false,
    double? maxDistanceKm,
    bool sortByDistance = false,
  }) {
    final filtered = _publications.where((p) {
      if (p.estado != EstadoPublicacion.activa) return false;
      if (categoryId != null && p.categoriaId != categoryId) return false;
      if (type != null && p.tipo != type) return false;
      if (urgency != null && p.urgencia != urgency) return false;
      if (maxDistanceKm != null &&
          (getDistanceForPublication(p) ?? double.infinity) > maxDistanceKm) {
        return false;
      }
      return true;
    }).toList();

    if (sortByUrgency || sortByDistance) {
      final distances = sortByDistance
          ? {
              for (final publication in filtered)
                publication.id: getDistanceForPublication(publication),
            }
          : const <String, double?>{};
      filtered.sort((a, b) {
        if (sortByUrgency) {
          final urgency = (a.urgencia?.index ?? 3).compareTo(
            b.urgencia?.index ?? 3,
          );
          if (urgency != 0) return urgency;
        }
        if (sortByDistance) {
          final distance = (distances[a.id] ?? double.infinity).compareTo(
            distances[b.id] ?? double.infinity,
          );
          if (distance != 0) return distance;
        }
        return b.fechaPublicacion.compareTo(a.fechaPublicacion);
      });
    }

    return List.unmodifiable(filtered);
  }

  List<CoincidenciaMock> getMatchesForUser(String userId) {
    final myActive = _publications.where(
      (p) => p.autorId == userId && p.estado == EstadoPublicacion.activa,
    );
    final otherActive = _publications.where(
      (p) => p.autorId != userId && p.estado == EstadoPublicacion.activa,
    );

    final matches = <CoincidenciaMock>[];
    for (final mine in myActive) {
      for (final other in otherActive) {
        if (mine.categoriaId != other.categoriaId || mine.tipo == other.tipo) {
          continue;
        }
        final need = mine.tipo == TipoPublicacion.necesidad ? mine : other;
        final item = mine.tipo == TipoPublicacion.articulo ? mine : other;
        final fulfilled = <String>[
          'Misma categoría',
          if (need.condicion == null || item.condicion == need.condicion)
            'Condición compatible',
          if (item.cantidad >= need.cantidad) 'Cantidad suficiente',
        ];
        matches.add(
          CoincidenciaMock(
            id: 'match-${mine.id}-${other.id}',
            publicacionPropiaId: mine.id,
            publicacionParId: other.id,
            necesidadId: need.id,
            articuloId: item.id,
            categoriaId: need.categoriaId,
            urgencia: need.urgencia ?? Urgencia.baja,
            distanciaKm: _distanceBetweenPublications(mine, other),
            caracteristicasCumplidas: List.unmodifiable(fulfilled),
          ),
        );
      }
    }

    matches.sort((a, b) {
      final urgencyCmp = a.urgencia.index.compareTo(b.urgencia.index);
      if (urgencyCmp != 0) return urgencyCmp;
      return (a.distanciaKm ?? double.infinity).compareTo(
        b.distanciaKm ?? double.infinity,
      );
    });
    return List.unmodifiable(matches);
  }

  List<NotificacionMock> getNotificationsForUser(String userId) {
    return List.unmodifiable(
      _notifications.where((n) => n.destinatarioId == userId),
    );
  }

  Future<void> markNotificationAsRead(String notificationId) =>
      markNotificationsAsRead([notificationId]);

  Future<void> markNotificationsAsRead(List<String> ids) async {
    final selected = ids.toSet();
    for (var index = 0; index < _notifications.length; index++) {
      final notification = _notifications[index];
      if (selected.contains(notification.id) && !notification.leida) {
        _notifications[index] = notification.copyWith(leida: true);
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bloque 4: Propuestas, Donaciones, Chat, Historial y Reseñas (CU-23..CU-39)
  // ---------------------------------------------------------------------------

  bool hasPendingProposal({
    required String publicationId,
    required String userId,
  }) {
    return _proposals.any(
      (p) =>
          p.publicacionId == publicationId &&
          p.remitenteId == userId &&
          p.estado == EstadoPropuesta.pendiente,
    );
  }

  Future<PropuestaMock> createRequestProposal({
    required String publicationId,
    required String senderId,
    required String message,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();

    final existingByKey = _findProposalByClientKey(clientKey);
    if (existingByKey != null) return existingByKey;

    final pub = findPublicationById(publicationId);
    if (pub == null || pub.tipo != TipoPublicacion.articulo) {
      throw const ValidationException(
        'Publicación no encontrada o no es un artículo.',
      );
    }
    if (pub.estado != EstadoPublicacion.activa) {
      throw const ValidationException('Este artículo ya no está activo.');
    }
    if (senderId == pub.autorId) {
      throw const ValidationException(
        'No puedes solicitar tu propio artículo.',
      );
    }
    final sender = findUserById(senderId);
    if (sender == null) {
      throw const ValidationException('Usuario remitente no encontrado.');
    }
    if (hasPendingProposal(publicationId: publicationId, userId: senderId)) {
      throw const ValidationException(
        'Ya tienes una solicitud pendiente para este artículo.',
      );
    }

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty || cleanMessage.length > 300) {
      throw const ValidationException(
        'El mensaje debe tener entre 1 y 300 caracteres.',
      );
    }

    final proposal = PropuestaMock(
      id: 'prop-${++_propSeq}',
      publicacionId: publicationId,
      remitenteId: senderId,
      tipo: TipoPropuesta.solicitud,
      texto: cleanMessage,
      estado: EstadoPropuesta.pendiente,
      fechaEnvio: _currentTime,
      claveCliente: clientKey,
    );
    _proposals.add(proposal);

    _emitNotification(
      destinatarioId: pub.autorId,
      publicacionId: pub.id,
      tipo: TipoNotificacion.nuevaPropuesta,
      mensaje:
          '${sender.nombreLegal} envió una solicitud para tu artículo "${pub.titulo}".',
    );
    notifyListeners();
    return proposal;
  }

  Future<PropuestaMock> createOfferProposal({
    required String publicationId,
    required String senderId,
    required String description,
    required List<String> photos,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();

    final existingByKey = _findProposalByClientKey(clientKey);
    if (existingByKey != null) return existingByKey;

    final pub = findPublicationById(publicationId);
    if (pub == null || pub.tipo != TipoPublicacion.necesidad) {
      throw const ValidationException(
        'Publicación no encontrada o no es una necesidad.',
      );
    }
    if (pub.estado != EstadoPublicacion.activa) {
      throw const ValidationException('Esta necesidad ya no está activa.');
    }
    if (senderId == pub.autorId) {
      throw const ValidationException(
        'No puedes ofertar en tu propia necesidad.',
      );
    }
    final sender = findUserById(senderId);
    if (sender == null) {
      throw const ValidationException('Usuario remitente no encontrado.');
    }
    if (hasPendingProposal(publicationId: publicationId, userId: senderId)) {
      throw const ValidationException(
        'Ya enviaste una oferta pendiente para esta necesidad.',
      );
    }

    final cleanDescription = description.trim();
    if (cleanDescription.isEmpty) {
      throw const ValidationException(
        'La descripción del artículo ofrecido es obligatoria.',
      );
    }
    if (photos.isEmpty || photos.length > 5) {
      throw const ValidationException(
        'Debes adjuntar entre 1 y 5 fotografías.',
      );
    }

    final proposal = PropuestaMock(
      id: 'prop-${++_propSeq}',
      publicacionId: publicationId,
      remitenteId: senderId,
      tipo: TipoPropuesta.oferta,
      texto: cleanDescription,
      fotografias: List.unmodifiable(photos),
      estado: EstadoPropuesta.pendiente,
      fechaEnvio: _currentTime,
      claveCliente: clientKey,
    );
    _proposals.add(proposal);

    _emitNotification(
      destinatarioId: pub.autorId,
      publicacionId: pub.id,
      tipo: TipoNotificacion.nuevaPropuesta,
      mensaje:
          '${sender.nombreLegal} envió una oferta para cubrir "${pub.titulo}".',
    );
    notifyListeners();
    return proposal;
  }

  Future<void> withdrawProposal(String proposalId) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para retirar una propuesta.',
    );

    final idx = _proposals.indexWhere((p) => p.id == proposalId);
    if (idx == -1) {
      throw const ValidationException('Propuesta no encontrada.');
    }
    final proposal = _proposals[idx];
    if (proposal.remitenteId != actor.id) {
      throw const UnauthorizedActionException(
        'Solo el remitente puede retirar esta propuesta.',
      );
    }
    if (proposal.estado != EstadoPropuesta.pendiente) {
      throw const ValidationException(
        'Solo se pueden retirar propuestas pendientes.',
      );
    }

    _proposals[idx] = proposal.copyWith(estado: EstadoPropuesta.retirada);
    notifyListeners();
  }

  List<PropuestaMock> getReceivedPendingProposals(
    String authorId, {
    String? publicationId,
  }) {
    final authorPubIds = _publications
        .where(
          (p) =>
              p.autorId == authorId &&
              (publicationId == null || p.id == publicationId),
        )
        .map((p) => p.id)
        .toSet();
    return List.unmodifiable(
      _proposals.where(
        (p) =>
            p.estado == EstadoPropuesta.pendiente &&
            authorPubIds.contains(p.publicacionId),
      ),
    );
  }

  List<PropuestaMock> getSentProposals(String senderId) {
    return List.unmodifiable(
      _proposals.where((p) => p.remitenteId == senderId),
    );
  }

  Future<DonacionMock> acceptProposal({
    required String proposalId,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para aceptar una propuesta.',
    );

    final existingByKey = _findDonationByIdempotencyKey('accept:$clientKey');
    if (existingByKey != null) return existingByKey;

    final propIdx = _proposals.indexWhere((p) => p.id == proposalId);
    if (propIdx == -1) {
      throw const ValidationException('Propuesta no encontrada.');
    }
    final proposal = _proposals[propIdx];

    final pubIdx = _publications.indexWhere(
      (p) => p.id == proposal.publicacionId,
    );
    if (pubIdx == -1) {
      throw const ValidationException('Publicación asociada no encontrada.');
    }
    final pub = _publications[pubIdx];

    if (actor.id != pub.autorId) {
      throw const UnauthorizedActionException(
        'Solo el autor de la publicación puede aceptar propuestas.',
      );
    }

    if (proposal.estado == EstadoPropuesta.aceptada) {
      for (final d in _donations) {
        if (d.propuestaId == proposal.id) {
          _donationClientKeys['accept:$clientKey'] = d.id;
          return d;
        }
      }
    }

    if (proposal.estado != EstadoPropuesta.pendiente) {
      throw const ValidationException('La propuesta ya no está pendiente.');
    }
    if (pub.estado != EstadoPublicacion.activa) {
      throw const ValidationException('La publicación ya no está activa.');
    }

    final isArticle = pub.tipo == TipoPublicacion.articulo;
    final donanteId = isArticle ? pub.autorId : proposal.remitenteId;
    final donatarioId = isArticle ? proposal.remitenteId : pub.autorId;
    final intermediarioId = (!isArticle && pub.gestionadaPorIntermediario)
        ? pub.autorId
        : null;

    _proposals[propIdx] = proposal.copyWith(estado: EstadoPropuesta.aceptada);
    _publications[pubIdx] = pub.copyWith(estado: EstadoPublicacion.reservada);

    for (var i = 0; i < _proposals.length; i++) {
      final other = _proposals[i];
      if (other.id != proposal.id &&
          other.publicacionId == pub.id &&
          other.estado == EstadoPropuesta.pendiente) {
        _proposals[i] = other.copyWith(
          estado: EstadoPropuesta.rechazada,
          motivoRechazo: 'Otra propuesta fue aceptada para esta publicación.',
        );
        _emitNotification(
          destinatarioId: other.remitenteId,
          publicacionId: pub.id,
          tipo: TipoNotificacion.propuestaRechazada,
          mensaje:
              'Tu propuesta para "${pub.titulo}" fue rechazada porque se aceptó otra propuesta.',
        );
      }
    }

    final donation = DonacionMock(
      id: 'don-${++_donSeq}',
      publicacionId: pub.id,
      propuestaId: proposal.id,
      donanteId: donanteId,
      donatarioId: donatarioId,
      intermediarioId: intermediarioId,
      estado: EstadoDonacion.aceptada,
      historialCambios: List.unmodifiable([
        CambioEstadoMock(
          estadoAnterior: null,
          estadoNuevo: EstadoDonacion.aceptada,
          fechaHora: _currentTime,
          actorId: actor.id,
          nota: 'Propuesta aceptada y donación iniciada',
        ),
      ]),
    );

    _donations.add(donation);
    _donationClientKeys['accept:$clientKey'] = donation.id;

    _emitNotification(
      destinatarioId: proposal.remitenteId,
      publicacionId: pub.id,
      donacionId: donation.id,
      tipo: TipoNotificacion.propuestaAceptada,
      mensaje:
          '¡Tu propuesta para "${pub.titulo}" fue aceptada! Ya pueden coordinar la entrega.',
    );
    _emitNotification(
      destinatarioId: pub.autorId,
      publicacionId: pub.id,
      donacionId: donation.id,
      tipo: TipoNotificacion.cambioEstadoDonacion,
      mensaje: 'Se inició la donación para "${pub.titulo}".',
    );

    notifyListeners();
    return donation;
  }

  Future<void> rejectProposal({
    required String proposalId,
    String? reason,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para rechazar una propuesta.',
    );

    final propIdx = _proposals.indexWhere((p) => p.id == proposalId);
    if (propIdx == -1) {
      throw const ValidationException('Propuesta no encontrada.');
    }
    final proposal = _proposals[propIdx];
    final pub = findPublicationById(proposal.publicacionId);
    if (pub == null) {
      throw const ValidationException('Publicación asociada no encontrada.');
    }
    if (actor.id != pub.autorId) {
      throw const UnauthorizedActionException(
        'Solo el autor de la publicación puede rechazar propuestas.',
      );
    }
    if (proposal.estado != EstadoPropuesta.pendiente) {
      throw const ValidationException('La propuesta ya no está pendiente.');
    }

    final cleanReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : null;
    _proposals[propIdx] = proposal.copyWith(
      estado: EstadoPropuesta.rechazada,
      motivoRechazo: cleanReason,
    );

    final reasonSuffix = cleanReason != null ? ' Motivo: $cleanReason' : '';
    _emitNotification(
      destinatarioId: proposal.remitenteId,
      publicacionId: pub.id,
      tipo: TipoNotificacion.propuestaRechazada,
      mensaje: 'Tu propuesta para "${pub.titulo}" fue rechazada.$reasonSuffix',
    );
    _emitNotification(
      destinatarioId: pub.autorId,
      publicacionId: pub.id,
      tipo: TipoNotificacion.propuestaRechazada,
      mensaje:
          'Rechazaste la propuesta para "${pub.titulo}". La publicación sigue activa.',
    );

    notifyListeners();
  }

  Future<DonacionMock> registerDeliverySchedule({
    required String donationId,
    required String place,
    required DateTime scheduledDate,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para coordinar la entrega.',
    );

    final existingByKey = _findDonationByIdempotencyKey(
      'schedule:$donationId:$clientKey',
    );
    if (existingByKey != null) return existingByKey;

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    _ensureDonationParticipant(donation, actor.id);

    if (donation.estado != EstadoDonacion.aceptada) {
      throw const ValidationException(
        'Solo se puede registrar lugar y fecha cuando la donación está Aceptada.',
      );
    }
    final cleanPlace = place.trim();
    if (cleanPlace.isEmpty) {
      throw const ValidationException('El lugar de entrega es obligatorio.');
    }

    final updated = donation.copyWith(
      estado: EstadoDonacion.enEntrega,
      lugarEntrega: cleanPlace,
      fechaEntregaAcordada: scheduledDate,
      historialCambios: List.unmodifiable([
        ...donation.historialCambios,
        CambioEstadoMock(
          estadoAnterior: EstadoDonacion.aceptada,
          estadoNuevo: EstadoDonacion.enEntrega,
          fechaHora: _currentTime,
          actorId: actor.id,
          nota: 'Lugar y fecha acordados: $cleanPlace',
        ),
      ]),
    );

    _donations[idx] = updated;
    _donationClientKeys['schedule:$donationId:$clientKey'] = updated.id;
    _notifyDonationParties(
      updated,
      'Entrega programada en $cleanPlace para la donación ${updated.id}.',
    );
    notifyListeners();
    return updated;
  }

  Future<DonacionMock> markDonationDelivered({
    required String donationId,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para marcar la entrega.',
    );

    final existingByKey = _findDonationByIdempotencyKey(
      'deliver:$donationId:$clientKey',
    );
    if (existingByKey != null) return existingByKey;

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    if (actor.id != donation.donanteId) {
      throw const UnauthorizedActionException(
        'Solo el donante puede marcar la donación como entregada.',
      );
    }
    if (donation.estado != EstadoDonacion.enEntrega) {
      throw const ValidationException(
        'La donación debe estar En entrega para marcarse como entregada.',
      );
    }

    final updated = donation.copyWith(
      estado: EstadoDonacion.entregada,
      fechaEntregada: _currentTime,
      historialCambios: List.unmodifiable([
        ...donation.historialCambios,
        CambioEstadoMock(
          estadoAnterior: EstadoDonacion.enEntrega,
          estadoNuevo: EstadoDonacion.entregada,
          fechaHora: _currentTime,
          actorId: actor.id,
          nota: 'Donante marcó como entregada',
        ),
      ]),
    );

    _donations[idx] = updated;
    _donationClientKeys['deliver:$donationId:$clientKey'] = updated.id;
    _emitNotification(
      destinatarioId: updated.donatarioId,
      publicacionId: updated.publicacionId,
      donacionId: updated.id,
      tipo: TipoNotificacion.cambioEstadoDonacion,
      mensaje: 'El donante marcó la entrega como realizada. Por favor confirma la recepción.',
    );
    notifyListeners();
    return updated;
  }

  Future<DonacionMock> confirmDonationReceived({
    required String donationId,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para confirmar la recepción.',
    );

    final existingByKey = _findDonationByIdempotencyKey(
      'confirm:$donationId:$clientKey',
    );
    if (existingByKey != null) return existingByKey;

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    if (actor.id != donation.donatarioId &&
        actor.id != donation.intermediarioId) {
      throw const UnauthorizedActionException(
        'Solo el donatario o intermediario puede confirmar la recepción.',
      );
    }
    if (donation.estado != EstadoDonacion.entregada) {
      throw const ValidationException(
        'La donación debe estar en estado Entregada para confirmar la recepción.',
      );
    }

    final updated = _finalizeDonationAtIndex(
      idx,
      actorId: actor.id,
      note: 'Recepción confirmada por el donatario',
    );
    _donationClientKeys['confirm:$donationId:$clientKey'] = updated.id;
    notifyListeners();
    return updated;
  }

  /// Automatically finalizes delivered donations after 7 days without confirmation (CU-34 2a).
  int runAutomaticFinalizationCheck() {
    var count = 0;
    for (var i = 0; i < _donations.length; i++) {
      final donation = _donations[i];
      if (donation.estado == EstadoDonacion.entregada &&
          donation.fechaEntregada != null &&
          _currentTime.difference(donation.fechaEntregada!).inDays >= 7) {
        _finalizeDonationAtIndex(
          i,
          actorId: null,
          note: 'Finalización automática del Sistema tras 7 días sin respuesta',
        );
        count++;
      }
    }
    if (count > 0) {
      notifyListeners();
    }
    return count;
  }

  Future<DonacionMock> cancelDonation({
    required String donationId,
    required String reason,
    required String clientKey,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para cancelar una donación.',
    );

    final existingByKey = _findDonationByIdempotencyKey(
      'cancel:$donationId:$clientKey',
    );
    if (existingByKey != null) return existingByKey;

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    _ensureDonationParticipant(donation, actor.id);

    if (donation.estado != EstadoDonacion.aceptada &&
        donation.estado != EstadoDonacion.enEntrega) {
      throw const ValidationException(
        'Solo se puede cancelar una donación en estado Aceptada o En entrega.',
      );
    }
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const ValidationException(
        'Debes indicar el motivo de la cancelación.',
      );
    }

    final updated = donation.copyWith(
      estado: EstadoDonacion.cancelada,
      motivoCancelacion: cleanReason,
      historialCambios: List.unmodifiable([
        ...donation.historialCambios,
        CambioEstadoMock(
          estadoAnterior: donation.estado,
          estadoNuevo: EstadoDonacion.cancelada,
          fechaHora: _currentTime,
          actorId: actor.id,
          nota: 'Cancelada: $cleanReason',
        ),
      ]),
    );
    _donations[idx] = updated;
    _donationClientKeys['cancel:$donationId:$clientKey'] = updated.id;

    // Reactivate publication unless it belonged to a revoked intermediary.
    final pubIdx = _publications.indexWhere(
      (p) => p.id == donation.publicacionId,
    );
    if (pubIdx != -1) {
      final pub = _publications[pubIdx];
      final author = findUserById(pub.autorId);
      final keepWithdrawn =
          pub.tipo == TipoPublicacion.necesidad &&
          pub.gestionadaPorIntermediario &&
          (author == null || !author.esIntermediario);
      _publications[pubIdx] = pub.copyWith(
        estado: keepWithdrawn
            ? EstadoPublicacion.retirada
            : EstadoPublicacion.activa,
      );
    }

    _notifyDonationParties(
      updated,
      'La donación fue cancelada. Motivo: $cleanReason',
    );
    notifyListeners();
    return updated;
  }

  Future<MensajeMock> sendChatMessage({
    required String donationId,
    required String content,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para enviar mensajes.',
    );

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    _ensureDonationParticipant(donation, actor.id);

    if (!donation.chatDisponible) {
      throw const ValidationException(
        'El chat solo está disponible mientras la donación está Aceptada o En entrega.',
      );
    }
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) {
      throw const ValidationException('El mensaje no puede estar vacío.');
    }

    final msg = MensajeMock(
      id: 'msg-${++_msgSeq}',
      donacionId: donationId,
      remitenteId: actor.id,
      contenido: cleanContent,
      fechaHora: _currentTime,
    );
    _donations[idx] = donation.copyWith(
      mensajes: List.unmodifiable([...donation.mensajes, msg]),
    );
    notifyListeners();
    return msg;
  }

  Future<DonacionMock> toggleSharePhoneInDonation({
    required String donationId,
    required bool share,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para cambiar la visibilidad del teléfono.',
    );

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    _ensureDonationParticipant(donation, actor.id);

    final updated = actor.id == donation.donanteId
        ? donation.copyWith(telefonoDonanteCompartido: share)
        : donation.copyWith(telefonoDonatarioCompartido: share);
    _donations[idx] = updated;
    notifyListeners();
    return updated;
  }

  Future<ResenaMock> submitReview({
    required String donationId,
    required int rating,
    String? comment,
  }) async {
    _ensureNetworkAvailable();
    final actor = _requireAuthenticatedUser(
      'Debes iniciar sesión para enviar una reseña.',
    );

    final idx = _findDonationIndexOrThrow(donationId);
    final donation = _donations[idx];
    _ensureDonationParticipant(donation, actor.id);

    if (donation.estado != EstadoDonacion.finalizada) {
      throw const ValidationException(
        'Solo puedes reseñar una donación finalizada.',
      );
    }
    if (_reviews.any(
      (r) => r.donacionId == donationId && r.autorId == actor.id,
    )) {
      throw const ValidationException(
        'Ya enviaste una reseña para esta donación.',
      );
    }
    if (donation.fechaFinalizacion == null ||
        _currentTime.difference(donation.fechaFinalizacion!).inDays > 14) {
      throw const ValidationException(
        'El plazo de 14 días para reseñar esta donación ha vencido.',
      );
    }
    if (rating < 1 || rating > 5) {
      throw const ValidationException(
        'La calificación debe estar entre 1 y 5 estrellas.',
      );
    }

    final cleanComment = (comment != null && comment.trim().isNotEmpty)
        ? comment.trim()
        : null;
    if ((cleanComment?.length ?? 0) > 500) {
      throw const ValidationException(
        'El comentario no puede superar los 500 caracteres.',
      );
    }

    final reviewedUserId = actor.id == donation.donanteId
        ? donation.donatarioId
        : donation.donanteId;
    final review = ResenaMock(
      id: 'rev-${++_revSeq}',
      donacionId: donationId,
      autorId: actor.id,
      resenadoId: reviewedUserId,
      calificacion: rating,
      comentario: cleanComment,
      fecha: _currentTime,
      verificada: true,
    );

    _reviews.add(review);
    _recalculateTrustProfileInternal(reviewedUserId);
    notifyListeners();
    return review;
  }

  List<DonacionMock> getActiveDonationsForUser(String userId) {
    return List.unmodifiable(
      _donations.where(
        (d) =>
            (d.donanteId == userId ||
                d.donatarioId == userId ||
                d.intermediarioId == userId) &&
            (d.estado == EstadoDonacion.aceptada ||
                d.estado == EstadoDonacion.enEntrega ||
                d.estado == EstadoDonacion.entregada),
      ),
    );
  }

  List<DonacionMock> getDonationHistoryForUser(
    String userId, {
    PapelDonacion? role,
    EstadoDonacion? finalState,
  }) {
    final filtered =
        _donations.where((d) {
          final isTerminal =
              d.estado == EstadoDonacion.finalizada ||
              d.estado == EstadoDonacion.cancelada;
          if (!isTerminal) return false;
          if (finalState != null && d.estado != finalState) return false;
          switch (role) {
            case PapelDonacion.donante:
              return d.donanteId == userId;
            case PapelDonacion.donatario:
              return d.donatarioId == userId;
            case null:
              return d.donanteId == userId || d.donatarioId == userId;
          }
        }).toList()..sort((a, b) {
          final dateA =
              a.fechaFinalizacion ?? a.historialCambios.last.fechaHora;
          final dateB =
              b.fechaFinalizacion ?? b.historialCambios.last.fechaHora;
          return dateB.compareTo(dateA);
        });
    return List.unmodifiable(filtered);
  }

  // ---------------------------------------------------------------------------
  // Bloque 5: Intermediarios y Administración (CU-40 a CU-51)
  // ---------------------------------------------------------------------------

  Future<SolicitudRolIntermediarioMock> requestIntermediaryRole({
    required String organization,
    required String documentName,
    required int documentBytes,
  }) async {
    _ensureNetworkAvailable();
    final user = _requireAuthenticatedUser(
      'Debes iniciar sesión para solicitar el rol de intermediario.',
    );

    if (user.esIntermediario) {
      throw const ValidationException(
        'Ya cuentas con el rol de intermediario autorizado.',
      );
    }
    if (_intermediaryRequests.any(
      (r) => r.usuarioId == user.id && r.estado == EstadoSolicitudRol.pendiente,
    )) {
      throw const ValidationException(
        'Ya tienes una solicitud de rol pendiente.',
      );
    }

    final cleanOrg = organization.trim();
    if (cleanOrg.isEmpty) {
      throw const ValidationException(
        'El nombre de la organización o comunidad es obligatorio.',
      );
    }

    final cleanDoc = documentName.trim();
    final lowerDoc = cleanDoc.toLowerCase();
    if (cleanDoc.isEmpty ||
        !_allowedDocumentExtensions.any((ext) => lowerDoc.endsWith(ext))) {
      throw const ValidationException(
        'El documento de respaldo debe ser .pdf, .jpg, .jpeg o .png.',
      );
    }
    if (documentBytes <= 0 || documentBytes > _maxDocumentBytes) {
      throw const ValidationException(
        'El documento de respaldo debe pesar máximo 5 MB.',
      );
    }

    final request = SolicitudRolIntermediarioMock(
      id: 'rol-${++_rolSeq}',
      usuarioId: user.id,
      organizacion: cleanOrg,
      documentoNombre: cleanDoc,
      documentoBytesSimulados: documentBytes,
      estado: EstadoSolicitudRol.pendiente,
      fechaSolicitud: _currentTime,
    );
    _intermediaryRequests.add(request);
    notifyListeners();
    return request;
  }

  Future<void> approveIntermediaryRequest(String requestId) async {
    _ensureNetworkAvailable();
    final admin = _requireAdmin();

    final idx = _findPendingIntermediaryRequestIndex(requestId);
    final req = _intermediaryRequests[idx];

    _intermediaryRequests[idx] = req.copyWith(
      estado: EstadoSolicitudRol.aprobada,
      fechaDecision: _currentTime,
      revisadaPorAdminId: admin.id,
    );
    final userIdx = _users.indexWhere((u) => u.id == req.usuarioId);
    if (userIdx != -1) {
      _users[userIdx] = _users[userIdx].copyWith(esIntermediario: true);
    }

    _emitNotification(
      destinatarioId: req.usuarioId,
      publicacionId: '',
      tipo: TipoNotificacion.decisionRolIntermediario,
      mensaje:
          'Tu solicitud de rol de intermediario para "${req.organizacion}" fue aprobada.',
    );
    notifyListeners();
  }

  Future<void> rejectIntermediaryRequest(
    String requestId, {
    String? reason,
  }) async {
    _ensureNetworkAvailable();
    final admin = _requireAdmin();

    final idx = _findPendingIntermediaryRequestIndex(requestId);
    final req = _intermediaryRequests[idx];

    final cleanReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : null;
    _intermediaryRequests[idx] = req.copyWith(
      estado: EstadoSolicitudRol.rechazada,
      fechaDecision: _currentTime,
      revisadaPorAdminId: admin.id,
      motivoDecision: cleanReason,
    );

    final suffix = cleanReason != null ? ' Motivo: $cleanReason' : '';
    _emitNotification(
      destinatarioId: req.usuarioId,
      publicacionId: '',
      tipo: TipoNotificacion.decisionRolIntermediario,
      mensaje:
          'Tu solicitud de rol de intermediario para "${req.organizacion}" fue rechazada.$suffix',
    );
    notifyListeners();
  }

  Future<void> revokeIntermediaryRole(String userId) async {
    _ensureNetworkAvailable();
    final admin = _requireAdmin();

    final userIdx = _users.indexWhere((u) => u.id == userId);
    if (userIdx == -1) {
      throw const ValidationException('Usuario no encontrado.');
    }
    if (!_users[userIdx].esIntermediario) {
      throw const ValidationException(
        'El usuario no cuenta con rol de intermediario activo.',
      );
    }

    for (var i = 0; i < _intermediaryRequests.length; i++) {
      final req = _intermediaryRequests[i];
      if (req.usuarioId == userId &&
          req.estado == EstadoSolicitudRol.aprobada) {
        _intermediaryRequests[i] = req.copyWith(
          estado: EstadoSolicitudRol.revocada,
          fechaDecision: _currentTime,
          revisadaPorAdminId: admin.id,
        );
      }
    }

    _users[userIdx] = _users[userIdx].copyWith(esIntermediario: false);

    // Withdraw active intermediary-managed Needs and reject their pending offers.
    for (var i = 0; i < _publications.length; i++) {
      final pub = _publications[i];
      if (pub.autorId == userId &&
          pub.tipo == TipoPublicacion.necesidad &&
          pub.gestionadaPorIntermediario &&
          pub.estado == EstadoPublicacion.activa) {
        _withdrawPublicationAtIndex(
          i,
          rejectionReason: 'El rol de intermediario del autor fue revocado por administración.',
        );
      }
    }

    _emitNotification(
      destinatarioId: userId,
      publicacionId: '',
      tipo: TipoNotificacion.decisionRolIntermediario,
      mensaje: 'Tu rol de intermediario comunitario fue revocado.',
    );
    notifyListeners();
  }

  Future<CategoriaMock> createCategory({
    required String name,
    String iconKey = 'category',
  }) async {
    _ensureNetworkAvailable();
    _requireAdmin();

    final cleanName = _validateCategoryName(name);
    final category = CategoriaMock(
      id: 'cat-${++_catSeq}',
      nombre: cleanName,
      iconoClave: iconKey,
      activa: true,
    );
    _categories.add(category);
    notifyListeners();
    return category;
  }

  Future<CategoriaMock> renameCategory({
    required String categoryId,
    required String newName,
  }) async {
    _ensureNetworkAvailable();
    _requireAdmin();

    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx == -1) {
      throw const ValidationException('Categoría no encontrada.');
    }
    final cleanName = _validateCategoryName(
      newName,
      excludeCategoryId: categoryId,
    );

    final updated = _categories[idx].copyWith(nombre: cleanName);
    _categories[idx] = updated;
    notifyListeners();
    return updated;
  }

  Future<CategoriaMock> deactivateCategory(String categoryId) async {
    _ensureNetworkAvailable();
    _requireAdmin();

    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx == -1) {
      throw const ValidationException('Categoría no encontrada.');
    }

    final updated = _categories[idx].copyWith(activa: false);
    _categories[idx] = updated;
    notifyListeners();
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _ensureNetworkAvailable() {
    if (_simulateNetworkError) {
      throw const NetworkException();
    }
  }

  UsuarioMock _requireAuthenticatedUser(String message) {
    final user = activeUser;
    if (user == null) {
      throw UnauthorizedActionException(message);
    }
    return user;
  }

  UsuarioMock _requireAdmin() {
    final user = activeUser;
    if (user == null || !user.esAdministrador) {
      throw const UnauthorizedActionException(
        'Esta acción requiere permisos de administrador.',
      );
    }
    return user;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _stripLeadingAt(String value) {
    var result = value;
    while (result.startsWith('@')) {
      result = result.substring(1);
    }
    return result;
  }

  String _normalizeUsername(String username) {
    return _stripLeadingAt(username.trim().toLowerCase());
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void _validatePhone(String phone) {
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      throw const ValidationException(
        'El teléfono debe tener exactamente 10 dígitos numéricos.',
      );
    }
  }

  void _validatePassword(String password) {
    final valid =
        password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
    if (!valid) {
      throw const ValidationException(
        'La contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula y un número.',
      );
    }
  }

  void _validateNeedInput(CreateNeedInput input, UsuarioMock author) {
    if (input.titulo.trim().isEmpty) {
      throw const ValidationException('El título es obligatorio.');
    }
    if (input.descripcion.trim().isEmpty) {
      throw const ValidationException('La descripción es obligatoria.');
    }
    if (input.cantidadRequerida < 1) {
      throw const ValidationException(
        'La cantidad requerida debe ser al menos 1.',
      );
    }
    if (input.ubicacionEtiqueta.trim().isEmpty) {
      throw const ValidationException(
        'La ubicación aproximada (colonia o código postal) es obligatoria.',
      );
    }
    final category = findCategoryById(input.categoriaId);
    if (category == null || !category.activa) {
      throw const ValidationException(
        'Debes seleccionar una categoría activa.',
      );
    }
    if (input.gestionadaPorIntermediario) {
      if (!author.esIntermediario) {
        throw const UnauthorizedActionException(
          'Solo los intermediarios autorizados pueden publicar en nombre de un beneficiario.',
        );
      }
      if (input.aliasBeneficiario == null ||
          input.aliasBeneficiario!.trim().isEmpty) {
        throw const ValidationException(
          'El alias del beneficiario es obligatorio.',
        );
      }
    }
  }

  void _validateItemInput(CreateItemInput input) {
    if (input.titulo.trim().isEmpty) {
      throw const ValidationException('El título del artículo es obligatorio.');
    }
    if (input.descripcion.trim().isEmpty) {
      throw const ValidationException('La descripción es obligatoria.');
    }
    if (input.fotografias.isEmpty || input.fotografias.length > 5) {
      throw const ValidationException(
        'Debes adjuntar entre 1 y 5 fotografías.',
      );
    }
    if (input.cantidad < 1) {
      throw const ValidationException(
        'La cantidad disponible debe ser al menos 1.',
      );
    }
    if (input.ubicacionEtiqueta.trim().isEmpty) {
      throw const ValidationException(
        'La ubicación aproximada (colonia o código postal) es obligatoria.',
      );
    }
    final category = findCategoryById(input.categoriaId);
    if (category == null || !category.activa) {
      throw const ValidationException(
        'Debes seleccionar una categoría activa.',
      );
    }
    if (category.id != CategoriaMock.alimentacionId &&
        input.condicion == null) {
      throw const ValidationException(
        'Selecciona el estado físico del artículo.',
      );
    }
  }

  UbicacionMock _buildLocation(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('centro') || normalized.contains('72000')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 0.8,
        latitud: 19.0414,
        longitud: -98.2063,
      );
    }
    if (normalized.contains('la paz') || normalized.contains('72160')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 2.4,
        latitud: 19.0630,
        longitud: -98.2063,
      );
    }
    if (normalized.contains('san manuel') || normalized.contains('72570')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 3.1,
        latitud: 19.0135,
        longitud: -98.2063,
      );
    }
    if (normalized.contains('universidades') || normalized.contains('72589')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 4.6,
        latitud: 19.0000,
        longitud: -98.2063,
      );
    }
    if (normalized.contains('cholula') || normalized.contains('72760')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 10.1,
        latitud: 19.0630,
        longitud: -98.3000,
      );
    }
    if (normalized.contains('huejotzingo') || normalized.contains('74160')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 24.8,
        latitud: 19.1600,
        longitud: -98.4060,
      );
    }
    if (normalized.contains('atlixco') || normalized.contains('74200')) {
      return UbicacionMock(
        etiqueta: label,
        distanciaKmSimulada: 28.2,
        latitud: 18.9080,
        longitud: -98.4350,
      );
    }

    final hash = normalized.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) % 997,
    );
    final km = double.parse((1.5 + (hash % 180) / 10.0).toStringAsFixed(1));
    final latOffset = km / 111.32;
    return UbicacionMock(
      etiqueta: label,
      distanciaKmSimulada: km,
      latitud: 19.0414 + latOffset,
      longitud: -98.2063,
    );
  }

  void _withdrawPublicationAtIndex(
    int pubIndex, {
    required String rejectionReason,
  }) {
    final pub = _publications[pubIndex];
    _publications[pubIndex] = pub.copyWith(estado: EstadoPublicacion.retirada);

    for (var i = 0; i < _proposals.length; i++) {
      final proposal = _proposals[i];
      if (proposal.publicacionId == pub.id &&
          proposal.estado == EstadoPropuesta.pendiente) {
        _proposals[i] = proposal.copyWith(
          estado: EstadoPropuesta.rechazada,
          motivoRechazo: rejectionReason,
        );
        _emitNotification(
          destinatarioId: proposal.remitenteId,
          publicacionId: pub.id,
          tipo: TipoNotificacion.propuestaRechazada,
          mensaje:
              'Tu propuesta para "${pub.titulo}" fue rechazada: $rejectionReason',
        );
      }
    }
  }

  void _generateMatchNotificationsForPublication(PublicacionMock pub) {
    if (pub.estado != EstadoPublicacion.activa) return;
    for (final other in _publications) {
      if (other.id == pub.id ||
          other.autorId == pub.autorId ||
          other.estado != EstadoPublicacion.activa ||
          other.categoriaId != pub.categoriaId ||
          other.tipo == pub.tipo) {
        continue;
      }
      _emitMatchNotificationIfAbsent(
        destinatarioId: pub.autorId,
        otherPubId: other.id,
        ownTitle: pub.titulo,
        otherTitle: other.titulo,
      );
      _emitMatchNotificationIfAbsent(
        destinatarioId: other.autorId,
        otherPubId: pub.id,
        ownTitle: other.titulo,
        otherTitle: pub.titulo,
      );
    }
  }

  void _emitMatchNotificationIfAbsent({
    required String destinatarioId,
    required String otherPubId,
    required String ownTitle,
    required String otherTitle,
  }) {
    final alreadyExists = _notifications.any(
      (n) =>
          n.tipo == TipoNotificacion.nuevaCoincidencia &&
          n.destinatarioId == destinatarioId &&
          n.publicacionId == otherPubId,
    );
    if (alreadyExists) return;
    _emitNotification(
      destinatarioId: destinatarioId,
      publicacionId: otherPubId,
      tipo: TipoNotificacion.nuevaCoincidencia,
      mensaje: '¡Nueva coincidencia para "$ownTitle": "$otherTitle"!',
    );
  }

  DonacionMock _finalizeDonationAtIndex(
    int donationIndex, {
    required String? actorId,
    required String note,
  }) {
    final donation = _donations[donationIndex];
    final updated = donation.copyWith(
      estado: EstadoDonacion.finalizada,
      fechaFinalizacion: _currentTime,
      historialCambios: List.unmodifiable([
        ...donation.historialCambios,
        CambioEstadoMock(
          estadoAnterior: EstadoDonacion.entregada,
          estadoNuevo: EstadoDonacion.finalizada,
          fechaHora: _currentTime,
          actorId: actorId,
          nota: note,
        ),
      ]),
    );
    _donations[donationIndex] = updated;

    final pubIdx = _publications.indexWhere(
      (p) => p.id == updated.publicacionId,
    );
    if (pubIdx != -1) {
      _publications[pubIdx] = _publications[pubIdx].copyWith(
        estado: EstadoPublicacion.cerrada,
      );
    }

    _notifyDonationParties(updated, 'La donación ${updated.id} ha finalizado.');
    _recalculateTrustProfileInternal(updated.donanteId);
    _recalculateTrustProfileInternal(updated.donatarioId);
    return updated;
  }

  void _notifyDonationParties(DonacionMock donation, String message) {
    _emitNotification(
      destinatarioId: donation.donanteId,
      publicacionId: donation.publicacionId,
      donacionId: donation.id,
      tipo: TipoNotificacion.cambioEstadoDonacion,
      mensaje: message,
    );
    if (donation.donatarioId != donation.donanteId) {
      _emitNotification(
        destinatarioId: donation.donatarioId,
        publicacionId: donation.publicacionId,
        donacionId: donation.id,
        tipo: TipoNotificacion.cambioEstadoDonacion,
        mensaje: message,
      );
    }
  }

  void _emitNotification({
    required String destinatarioId,
    required String publicacionId,
    required TipoNotificacion tipo,
    required String mensaje,
    String? donacionId,
  }) {
    _notifications.insert(
      0,
      NotificacionMock(
        id: 'notif-${++_notifSeq}',
        destinatarioId: destinatarioId,
        publicacionId: publicacionId,
        mensaje: mensaje,
        fecha: _currentTime,
        tipo: tipo,
        donacionId: donacionId,
      ),
    );
  }

  PropuestaMock? _findProposalByClientKey(String clientKey) {
    for (final proposal in _proposals) {
      if (proposal.claveCliente == clientKey) return proposal;
    }
    return null;
  }

  DonacionMock? _findDonationByIdempotencyKey(String scopedKey) {
    final donationId = _donationClientKeys[scopedKey];
    if (donationId == null) return null;
    return findDonationById(donationId);
  }

  int _findDonationIndexOrThrow(String donationId) {
    final idx = _donations.indexWhere((d) => d.id == donationId);
    if (idx == -1) {
      throw const ValidationException('Donación no encontrada.');
    }
    return idx;
  }

  void _ensureDonationParticipant(DonacionMock donation, String userId) {
    if (userId != donation.donanteId &&
        userId != donation.donatarioId &&
        userId != donation.intermediarioId) {
      throw const UnauthorizedActionException(
        'Solo las partes de la donación pueden realizar esta acción.',
      );
    }
  }

  int _findEditablePublicationIndex(
    String publicationId, {
    required String actorId,
    TipoPublicacion? expectedType,
  }) {
    final idx = _publications.indexWhere((p) => p.id == publicationId);
    if (idx == -1) {
      throw const ValidationException('Publicación no encontrada.');
    }
    final existing = _publications[idx];
    if (expectedType != null && existing.tipo != expectedType) {
      throw const ValidationException('Tipo de publicación incompatible.');
    }
    if (existing.autorId != actorId) {
      throw const UnauthorizedActionException(
        'Solo el autor puede modificar esta publicación.',
      );
    }
    if (existing.estado != EstadoPublicacion.activa) {
      throw const ValidationException(
        'Solo se pueden modificar publicaciones activas.',
      );
    }
    return idx;
  }

  int _findPendingIntermediaryRequestIndex(String requestId) {
    final idx = _intermediaryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw const ValidationException('Solicitud no encontrada.');
    }
    if (_intermediaryRequests[idx].estado != EstadoSolicitudRol.pendiente) {
      throw const ValidationException(
        'Solo se pueden procesar solicitudes pendientes.',
      );
    }
    return idx;
  }

  String _validateCategoryName(String name, {String? excludeCategoryId}) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationException(
        'El nombre de la categoría es obligatorio.',
      );
    }
    final duplicated = _categories.any(
      (c) =>
          c.id != excludeCategoryId &&
          c.nombre.trim().toLowerCase() == cleanName.toLowerCase(),
    );
    if (duplicated) {
      throw const ValidationException(
        'Ya existe una categoría con ese nombre.',
      );
    }
    return cleanName;
  }
}
