part of 'mock_tenant_store.dart';

typedef _Row = Map<String, dynamic>;

/// Adapts the online API to the state observed by the existing screens.
class OnlineTenantStore extends MockTenantStore {
  static const _bucket = 'donaplus-publications';
  static const _photoScheme = 'donaplus-photo:';
  final sb.SupabaseClient client;
  final String? emailConfirmationUrl;
  final Future<UbicacionMock?> Function(String)? locationLookup;
  final _resolvedLocations = <String, UbicacionMock>{};
  final _locationRetryAt = <String, DateTime>{};
  final Map<String, String> _sharedPhones = {};
  final Random _random = Random.secure();
  late final Timer _poll;
  late final StreamSubscription<sb.AuthState> _authChanges;
  var _request = 0;
  var _applied = 0;
  var _disposed = false;
  var _polling = false;
  var _resolvingLocations = false;

  OnlineTenantStore(
    this.client, {
    this.emailConfirmationUrl,
    this.locationLookup,
  }) : super(seed: false) {
    _authChanges = client.auth.onAuthStateChange.listen((event) {
      if (event.session == null) {
        _clearSession();
      } else if (event.session!.user.id != _activeUserId) {
        unawaited(_refreshInBackground());
      }
    }, onError: (Object _) {});
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_refreshInBackground());
    });
    unawaited(_refreshInBackground());
  }

  @override
  bool get isOnline => true;

  @override
  DateTime get currentTime => DateTime.now();

  @override
  String sharedPhoneFor(String donationId, UsuarioMock counterpart) =>
      _sharedPhones[donationId] ?? '';

  @override
  List<String> getSampleItemPhotos() => const [];

  Future<void> _refreshInBackground() async {
    if (_polling || client.auth.currentUser == null || _disposed) return;
    _polling = true;
    try {
      await _refresh();
    } on Exception {
      // Keep the last authenticated snapshot while the connection is unstable.
    } finally {
      _polling = false;
    }
  }

  void _clearSession() {
    if (_disposed) return;
    _applied = ++_request;
    _activeUserId = null;
    _deviceLocation = null;
    _users.clear();
    _categories.clear();
    _publications.clear();
    _proposals.clear();
    _donations.clear();
    _reviews.clear();
    _notifications.clear();
    _resolvedLocations.clear();
    _locationRetryAt.clear();
    _sharedPhones.clear();
    notifyListeners();
  }

  Future<void> _refresh() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final request = ++_request;
    final snapshot = await _remote(
      () async => Map<String, dynamic>.from(
        await client.rpc('donaplus_snapshot') as Map,
      ),
    );
    if (_disposed ||
        client.auth.currentUser?.id != user.id ||
        request <= _applied) {
      return;
    }

    final profiles = _rows(snapshot['profiles'])
        .map(
          (row) => _profile(
            row,
            email: row['id'] == user.id ? user.email ?? '' : '',
            photo: row['id'] == user.id ? _profilePhoto(user) : null,
          ),
        )
        .toList();
    final categories = _rows(snapshot['categories'])
        .map(
          (row) => CategoriaMock(
            id: row['id'] as String,
            nombre: row['name'] as String,
            iconoClave: row['icon'] as String,
          ),
        )
        .toList();
    final publications = _rows(snapshot['publications'])
        .map(_publication)
        .toList();
    final proposals = _rows(snapshot['proposals']).map(_proposal).toList();
    final donations = _rows(snapshot['donations']);
    final parsedDonations = donations.map(_donation).toList();
    final reviews = _rows(snapshot['reviews']).map(_review).toList();
    final notifications = _rows(snapshot['notifications'])
        .map(_notification)
        .toList();
    _applied = request;
    _activeUserId = user.id;
    _users
      ..clear()
      ..addAll(profiles);
    _categories
      ..clear()
      ..addAll(categories);
    _publications
      ..clear()
      ..addAll(publications);
    _proposals
      ..clear()
      ..addAll(proposals);
    _donations
      ..clear()
      ..addAll(parsedDonations);
    _reviews
      ..clear()
      ..addAll(reviews);
    _notifications
      ..clear()
      ..addAll(notifications);
    _sharedPhones
      ..clear()
      ..addEntries(
        donations
            .where((row) => row['shared_phone'] is String)
            .map(
              (row) =>
                  MapEntry(row['id'] as String, row['shared_phone'] as String),
            ),
      );
    notifyListeners();
    unawaited(_resolveLocations(user.id));
  }

  static String _locationKey(String label) => label.trim().toLowerCase();

  UbicacionMock? _resolvedLocation(UbicacionMock? location) => location == null
      ? null
      : _resolvedLocations[_locationKey(location.etiqueta)];

  UbicacionMock? get _distanceOrigin =>
      _deviceLocation ?? _resolvedLocation(activeUser?.ubicacionAproximada);

  @override
  bool get canFilterByDistance => _distanceOrigin != null;

  @override
  void setDeviceLocationAuthorized(bool authorized, {UbicacionMock? location}) {
    super.setDeviceLocationAuthorized(
      authorized && location != null,
      location: location,
    );
  }

  @override
  double? getDistanceForPublication(PublicacionMock publication) {
    final target = _resolvedLocation(publication.ubicacion);
    return target == null ? null : _distanceOrigin?.distanceKmTo(target);
  }

  @override
  double? _distanceBetweenPublications(
    PublicacionMock first,
    PublicacionMock second,
  ) {
    final target = _resolvedLocation(second.ubicacion);
    return target == null
        ? null
        : _resolvedLocation(first.ubicacion)?.distanceKmTo(target);
  }

  Future<void> _resolveLocations(String userId) async {
    final lookup = locationLookup;
    if (lookup == null || _resolvingLocations || _disposed) return;

    final now = DateTime.now();
    final labels =
        <String>{
          if (activeUser case final user?)
            _locationKey(user.ubicacionAproximada.etiqueta),
          for (final publication in _publications)
            if (publication.estado == EstadoPublicacion.activa)
              _locationKey(publication.ubicacion.etiqueta),
        }..removeWhere(
          (key) =>
              key.isEmpty ||
              _resolvedLocations.containsKey(key) ||
              (_locationRetryAt[key]?.isAfter(now) ?? false),
        );
    if (labels.isEmpty) return;

    _resolvingLocations = true;
    try {
      final pending = labels.toList();
      for (var offset = 0; offset < pending.length; offset += 4) {
        await Future.wait(
          pending.skip(offset).take(4).map((key) async {
            UbicacionMock? location;
            try {
              location = await lookup(key);
            } on Exception {
              // Retry an unavailable geocoder on a later refresh.
            }
            if (_disposed || client.auth.currentUser?.id != userId) return;
            if (location == null) {
              _locationRetryAt[key] = DateTime.now().add(
                const Duration(minutes: 2),
              );
            } else {
              _locationRetryAt.remove(key);
              _resolvedLocations[key] = location;
            }
          }),
        );
        if (_disposed || client.auth.currentUser?.id != userId) return;
        notifyListeners();
      }
    } finally {
      _resolvingLocations = false;
    }
  }

  @override
  Future<void> markNotificationsAsRead(List<String> ids) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || ids.isEmpty) return;
    await _remote(
      () => client.rpc(
        'komuna_mark_notifications_read',
        params: {'notification_ids': ids},
      ),
    );
    if (_disposed || client.auth.currentUser?.id != userId) return;
    _applied = ++_request;
    await super.markNotificationsAsRead(ids);
  }

  @override
  Future<UsuarioMock> registerUser(RegisterUserInput input) async {
    try {
      final response = await client.auth
          .signUp(
            email: input.correo.trim(),
            password: input.password,
            emailRedirectTo: emailConfirmationUrl,
            data: {
              'username': input.nombreUsuario.trim(),
              'name': input.nombreLegal.trim(),
              'phone': input.telefono.trim(),
              'location': input.ubicacionEtiqueta.trim(),
              'privacy_accepted': input.avisoPrivacidadAceptado,
            },
          )
          .timeout(const Duration(seconds: 15));
      final user = response.user;
      if (user == null || user.identities?.isEmpty == true) {
        throw const ValidationException(
          'No se pudo crear la cuenta con ese correo.',
        );
      }
      return _profile(
        {
          'id': user.id,
          'username': input.nombreUsuario.trim(),
          'name': input.nombreLegal.trim(),
          'phone': input.telefono.trim(),
          'location': input.ubicacionEtiqueta.trim(),
          'created_at': user.createdAt,
        },
        email: user.email ?? input.correo,
        verified: response.session != null,
      );
    } on TimeoutException {
      throw const NetworkException(
        'El servidor tardó en responder. Revisa tu correo antes de volver a intentar el registro.',
      );
    } on sb.AuthRetryableFetchException catch (error) {
      if (error.message.toLowerCase().contains(
        'email address not authorized',
      )) {
        throw const ValidationException(
          'Komuna todavía no puede enviar el correo de verificación a esa dirección.',
        );
      }
      throw const NetworkException(
        'No se pudo confirmar el registro. Revisa tu correo y vuelve a intentar en unos minutos.',
      );
    } on sb.AuthException catch (error) {
      throw ValidationException(switch (error.code) {
        'email_address_not_authorized' => 'Komuna todavía no puede enviar el correo de verificación a esa dirección.',
        'over_email_send_rate_limit' => 'Komuna alcanzó el límite de correos de confirmación. Si ya confirmaste tu cuenta, inicia sesión. Para pedir otro correo, puede hacer falta esperar hasta una hora.',
        'over_request_rate_limit' => 'Se alcanzó el límite de intentos. Espera unos minutos antes de volver a intentar.',
        'email_address_invalid' => 'El servicio rechazó esa dirección de correo. Revisa que esté bien escrita o usa otro correo al que tengas acceso.',
        'weak_password' =>
          'Elige una contraseña más fuerte e inténtalo de nuevo.',
        'unexpected_failure' => 'No se pudo registrar la cuenta. Revisa que el nombre de usuario esté disponible.',
        _ => 'No se pudo registrar la cuenta con esos datos.',
      });
    }
  }

  @override
  Future<UsuarioMock> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final email = usernameOrEmail.trim();
    if (!email.contains('@')) {
      throw const ValidationException(
        'Ingresa el correo con el que registraste tu cuenta.',
      );
    }
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      await _refresh();
      return activeUser ?? (throw const NetworkException());
    } on sb.AuthRetryableFetchException {
      throw const NetworkException();
    } on sb.AuthException catch (error) {
      if (error.code == 'email_not_confirmed') {
        throw const UnverifiedEmailException();
      }
      throw const InvalidCredentialsException();
    }
  }

  @override
  void logout() {
    _clearSession();
    unawaited(
      client.auth
          .signOut(scope: sb.SignOutScope.local)
          .catchError((Object _) {}),
    );
  }

  @override
  Future<UsuarioMock> updateProfile({
    String? fotoPerfil,
    required String telefono,
    String? newPassword,
  }) async {
    final user = _requireAuthenticatedUser(
      'Inicia sesión para editar tu perfil.',
    );
    _validatePhone(telefono.trim());
    final photoChanged = fotoPerfil != user.fotoPerfil;
    final avatarPath = photoChanged && fotoPerfil != null
        ? (await _uploadPhotos([fotoPerfil])).single
        : null;
    final password = newPassword?.isNotEmpty == true ? newPassword : null;
    if (photoChanged || password != null) {
      try {
        await client.auth
            .updateUser(
              sb.UserAttributes(
                password: password,
                data: photoChanged ? {'komuna_avatar': avatarPath} : null,
              ),
            )
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw const NetworkException();
      } on sb.AuthRetryableFetchException {
        throw const NetworkException();
      } on sb.AuthException {
        throw const ValidationException(
          'No se pudieron guardar los datos del perfil.',
        );
      }
    }
    await _write('profile', {
      'name': user.nombreLegal,
      'phone': telefono,
      'location': user.ubicacionAproximada.etiqueta,
    });
    return activeUser!;
  }

  Future<T> _remote<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(const Duration(seconds: 20));
    } on sb.PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const UnauthorizedActionException();
      }
      if (error.code == 'P0001') throw ValidationException(error.message);
      if (error.code == '23505') {
        throw const ValidationException('Esta acción ya se registró.');
      }
      if (error.code == '23514' || error.code == '23502') {
        throw const ValidationException(
          'Revisa los campos obligatorios y vuelve a intentarlo.',
        );
      }
      throw const NetworkException(
        'No se pudo completar la operación en el servidor.',
      );
    } on sb.StorageException {
      throw const NetworkException(
        'No se pudo subir la foto. Vuelve a intentarlo.',
      );
    } on TimeoutException {
      throw const NetworkException();
    } on SocketException {
      throw const NetworkException();
    } on Exception {
      throw const NetworkException();
    }
  }

  Future<String> _write(String operation, _Row payload) async {
    final id = await _remote(
      () async => await client.rpc(
        'donaplus_write',
        params: {'operation': operation, 'payload': payload},
      ) as String,
    );
    await _refresh();
    return id;
  }

  Future<List<String>> _uploadPhotos(List<String> photos) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const UnauthorizedActionException();
    if (photos.length > 5) {
      throw const ValidationException('Agrega máximo cinco fotografías.');
    }
    final paths = <String>[];
    for (final photo in photos) {
      if (photo.startsWith(_photoScheme)) {
        paths.add(photo.substring(_photoScheme.length));
        continue;
      }
      final uri = Uri.tryParse(photo);
      if (uri == null || uri.scheme != 'file' || kIsWeb) {
        throw const ValidationException(
          'Selecciona una foto de la cámara o galería.',
        );
      }
      final file = File.fromUri(uri);
      final extension = uri.pathSegments.last.split('.').last.toLowerCase();
      final type = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => null,
      };
      if (type == null) {
        throw const ValidationException(
          'Elige una imagen JPEG, PNG, WebP o HEIC.',
        );
      }
      final path =
          '$owner/${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}.$extension';
      try {
        if (await file.length() > 5 * 1024 * 1024) {
          throw const ValidationException(
            'Cada foto debe pesar como máximo 5 MB.',
          );
        }
        await _remote(
          () => client.storage
              .from(_bucket)
              .upload(
                path,
                file,
                fileOptions: sb.FileOptions(contentType: type),
              ),
        );
      } on FileSystemException {
        throw const ValidationException(
          'Vuelve a seleccionar la fotografía que ya no está disponible.',
        );
      }
      paths.add(path);
    }
    return paths;
  }

  Map<String, String>? photoHeaders(String photo) {
    final token = client.auth.currentSession?.accessToken;
    if (token == null || !photo.startsWith(_photoScheme)) return null;
    return {
      ...client.storage.from(_bucket).headers,
      'Authorization': 'Bearer $token',
    };
  }

  String photoUrl(String photo) {
    final path = photo.substring(_photoScheme.length);
    return '${client.storage.url}/object/authenticated/$_bucket/$path';
  }

  Future<PublicacionMock> _writeItem(
    CreateItemInput input, [
    String? id,
  ]) async {
    final result = await _write(id == null ? 'publish' : 'edit', {
      'id': id,
      'kind': 'articulo',
      'category': input.categoriaId,
      'title': input.titulo,
      'description': input.descripcion,
      'location': input.ubicacionEtiqueta,
      'quantity': input.cantidad,
      'condition': input.condicion?.name,
      if (input.caracteristicas != null) 'details': input.caracteristicas,
      'photos': await _uploadPhotos(input.fotografias),
    });
    return findPublicationById(result)!;
  }

  Future<PublicacionMock> _writeNeed(
    CreateNeedInput input, [
    String? id,
  ]) async {
    if (input.gestionadaPorIntermediario) {
      throw const ValidationException(
        'La gestión por intermediarios aún no está disponible en línea.',
      );
    }
    final result = await _write(id == null ? 'publish' : 'edit', {
      'id': id,
      'kind': 'necesidad',
      'category': input.categoriaId,
      'title': input.titulo,
      'description': input.descripcion,
      'location': input.ubicacionEtiqueta,
      'quantity': input.cantidadRequerida,
      'condition': input.condicionAceptable?.name,
      'urgency': input.urgencia.name,
      'details': {
        if (input.detallesCaracteristicas.trim().isNotEmpty)
          'Detalles': input.detallesCaracteristicas.trim(),
      },
    });
    return findPublicationById(result)!;
  }

  @override
  Future<PublicacionMock> createItemPublication(CreateItemInput input) =>
      _writeItem(input);

  @override
  Future<PublicacionMock> updateItemPublication({
    required String publicationId,
    required CreateItemInput input,
  }) => _writeItem(input, publicationId);

  @override
  Future<PublicacionMock> createNeedPublication(CreateNeedInput input) =>
      _writeNeed(input);

  @override
  Future<PublicacionMock> updateNeedPublication({
    required String publicationId,
    required CreateNeedInput input,
  }) => _writeNeed(input, publicationId);

  @override
  Future<void> withdrawPublication(String publicationId) async {
    await _write('withdraw_publication', {'id': publicationId});
  }

  Future<PropuestaMock> _propose(
    String id,
    String body,
    String key, [
    List<String> photos = const [],
  ]) async {
    final result = await _write('propose', {
      'id': id,
      'body': body,
      'client_key': key,
      'photos': await _uploadPhotos(photos),
    });
    return _proposals.firstWhere((proposal) => proposal.id == result);
  }

  @override
  Future<PropuestaMock> createRequestProposal({
    required String publicationId,
    required String senderId,
    required String message,
    required String clientKey,
  }) => _propose(publicationId, message, clientKey);

  @override
  Future<PropuestaMock> createOfferProposal({
    required String publicationId,
    required String senderId,
    required String description,
    required List<String> photos,
    required String clientKey,
  }) => _propose(publicationId, description, clientKey, photos);

  @override
  Future<void> withdrawProposal(String proposalId) async {
    await _write('withdraw_proposal', {'id': proposalId});
  }

  @override
  Future<void> rejectProposal({
    required String proposalId,
    String? reason,
  }) async {
    await _write('reject', {'id': proposalId, 'reason': reason});
  }

  Future<DonacionMock> _donationAction(
    String action,
    String id, [
    _Row details = const {},
  ]) async =>
      findDonationById(await _write(action, {'id': id, ...details})) ??
      (throw const UnauthorizedActionException());

  @override
  Future<DonacionMock> acceptProposal({
    required String proposalId,
    required String clientKey,
  }) => _donationAction('accept', proposalId, {'client_key': clientKey});

  @override
  Future<DonacionMock> registerDeliverySchedule({
    required String donationId,
    required String place,
    required DateTime scheduledDate,
    required String clientKey,
  }) => _donationAction('schedule', donationId, {
    'place': place,
    'date': scheduledDate.toUtc().toIso8601String(),
    'client_key': clientKey,
  });

  @override
  Future<DonacionMock> markDonationDelivered({
    required String donationId,
    required String clientKey,
  }) => _donationAction('deliver', donationId, {'client_key': clientKey});

  @override
  Future<DonacionMock> confirmDonationReceived({
    required String donationId,
    required String clientKey,
  }) => _donationAction('receive', donationId, {'client_key': clientKey});

  @override
  Future<DonacionMock> cancelDonation({
    required String donationId,
    required String reason,
    required String clientKey,
  }) => _donationAction('cancel', donationId, {
    'reason': reason,
    'client_key': clientKey,
  });

  @override
  Future<DonacionMock> toggleSharePhoneInDonation({
    required String donationId,
    required bool share,
  }) => _donationAction('share_phone', donationId, {'share': share});

  @override
  Future<MensajeMock> sendChatMessage({
    required String donationId,
    required String content,
  }) async {
    final id = await _write('message', {'id': donationId, 'body': content});
    return findDonationById(donationId)!.mensajes
        .firstWhere((message) => message.id == id);
  }

  @override
  void dispose() {
    _disposed = true;
    _poll.cancel();
    unawaited(_authChanges.cancel());
    super.dispose();
  }

  static Iterable<_Row> _rows(Object? objects) =>
      (objects as List? ?? const []).cast<_Row>();
  static DateTime _date(Object? value) =>
      DateTime.parse(value as String).toLocal();
  static DateTime? _maybeDate(Object? value) =>
      value == null ? null : _date(value);
  static List<String> _photos(Object? values) => (values as List? ?? const [])
      .map((value) => '$_photoScheme$value')
      .toList(growable: false);

  static NotificacionMock _notification(_Row row) => NotificacionMock(
    id: row['id'] as String,
    destinatarioId: row['recipient'] as String,
    publicacionId: row['publication'] as String,
    donacionId: row['donation'] as String?,
    mensaje: row['message'] as String,
    fecha: _date(row['created_at']),
    tipo: TipoNotificacion.values.byName(row['kind'] as String),
    leida: row['read_at'] != null,
  );

  static String? _profilePhoto(sb.User user) {
    final path = user.userMetadata?['komuna_avatar'];
    return path is String && path.startsWith('${user.id}/')
        ? '$_photoScheme$path'
        : null;
  }

  static UsuarioMock _profile(
    _Row row, {
    String email = '',
    String? photo,
    bool verified = true,
  }) => UsuarioMock(
    id: row['id'] as String,
    nombreUsuario: row['username'] as String,
    nombreLegal: row['name'] as String,
    correo: email,
    telefono: row['phone'] as String? ?? '',
    fotoPerfil: photo,
    ubicacionAproximada: UbicacionMock(
      etiqueta: row['location'] as String? ?? '',
    ),
    avisoPrivacidadAceptado: true,
    correoVerificado: verified,
    perfilConfianzaOtorgado: false,
    promedioCalificacion: 0,
    donacionesFinalizadas: 0,
    numeroResenas: 0,
    fechaRegistro: _maybeDate(row['created_at']),
  );

  static PublicacionMock _publication(_Row row) => PublicacionMock(
    id: row['id'] as String,
    tipo: TipoPublicacion.values.byName(row['kind'] as String),
    autorId: row['author'] as String,
    categoriaId: row['category'] as String,
    titulo: row['title'] as String,
    descripcion: row['description'] as String,
    estado: EstadoPublicacion.values.byName(row['state'] as String),
    ubicacion: UbicacionMock(etiqueta: row['location'] as String),
    fechaPublicacion: _date(row['created_at']),
    cantidad: row['quantity'] as int,
    condicion: row['condition'] == null
        ? null
        : CondicionArticulo.values.byName(row['condition'] as String),
    urgencia: row['urgency'] == null
        ? null
        : Urgencia.values.byName(row['urgency'] as String),
    caracteristicas: (row['details'] as Map).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    ),
    fotografias: _photos(row['photos']),
  );

  @override
  Future<ResenaMock> submitReview({
    required String donationId,
    required int rating,
    String? comment,
  }) async {
    final review = await _remote(
      () async => _review(
        Map<String, dynamic>.from(
          await client.rpc(
            'komuna_submit_review',
            params: {
              'donation_id': donationId,
              'rating': rating,
              'comment': comment,
            },
          ) as Map,
        ),
      ),
    );
    await _refresh();
    return review;
  }

  static ResenaMock _review(_Row row) => ResenaMock(
    id: row['id'] as String,
    donacionId: row['donation'] as String,
    autorId: row['author'] as String,
    resenadoId: row['reviewed'] as String,
    calificacion: row['rating'] as int,
    comentario: row['comment'] as String?,
    fecha: _date(row['created_at']),
  );

  static PropuestaMock _proposal(_Row row) => PropuestaMock(
    id: row['id'] as String,
    publicacionId: row['publication'] as String,
    remitenteId: row['sender'] as String,
    tipo: TipoPropuesta.values.byName(row['kind'] as String),
    texto: row['body'] as String,
    fotografias: _photos(row['photos']),
    estado: EstadoPropuesta.values.byName(row['state'] as String),
    fechaEnvio: _date(row['created_at']),
    claveCliente: row['client_key'] as String,
    motivoRechazo: row['rejection'] as String?,
  );

  static DonacionMock _donation(_Row row) {
    EstadoDonacion? previous;
    final history = <CambioEstadoMock>[];
    for (final entry in _rows(row['history'])) {
      final state = EstadoDonacion.values.byName(entry['state'] as String);
      history.add(
        CambioEstadoMock(
          estadoAnterior: previous,
          estadoNuevo: state,
          fechaHora: _date(entry['at']),
          actorId: entry['actor'] as String?,
        ),
      );
      previous = state;
    }
    return DonacionMock(
      id: row['id'] as String,
      publicacionId: row['publication'] as String,
      propuestaId: row['proposal'] as String,
      donanteId: row['donor'] as String,
      donatarioId: row['recipient'] as String,
      estado: EstadoDonacion.values.byName(row['state'] as String),
      lugarEntrega: row['place'] as String?,
      fechaEntregaAcordada: _maybeDate(row['scheduled_at']),
      fechaEntregada: _maybeDate(row['delivered_at']),
      fechaFinalizacion: _maybeDate(row['finished_at']),
      motivoCancelacion: row['cancellation'] as String?,
      telefonoDonanteCompartido: row['share_donor'] as bool,
      telefonoDonatarioCompartido: row['share_recipient'] as bool,
      historialCambios: history,
      mensajes: _rows(row['messages'])
          .map(
            (message) => MensajeMock(
              id: message['id'] as String,
              donacionId: message['donation'] as String,
              remitenteId: message['sender'] as String,
              contenido: message['body'] as String,
              fechaHora: _date(message['created_at']),
            ),
          )
          .toList(growable: false),
    );
  }
}
