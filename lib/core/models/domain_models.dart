import 'dart:math' as math;

/// Urgency levels required for Needs (CU-12).
enum Urgencia { alta, media, baja }

/// Publication lifecycle states.
enum EstadoPublicacion { activa, reservada, cerrada, retirada }

/// Physical condition options for donated items (RF-06, CU-14).
enum CondicionArticulo { nuevo, comoNuevo, usado }

enum PresentacionAlimento {
  latas('Latas'),
  botellas('Botellas'),
  sobres('Sobres'),
  otra('Otra presentación');

  const PresentacionAlimento(this.etiqueta);

  final String etiqueta;
}

/// Publication discriminator between Need and Item.
enum TipoPublicacion { necesidad, articulo }

/// Proposal discriminator between Request (CU-23) and Offer (CU-24).
enum TipoPropuesta { solicitud, oferta }

/// Proposal lifecycle states (CU-23 to CU-29).
enum EstadoPropuesta { pendiente, aceptada, rechazada, retirada }

/// Donation lifecycle states (CU-28 to CU-39).
enum EstadoDonacion { aceptada, enEntrega, entregada, finalizada, cancelada }

/// Intermediary role request states (CU-40 to CU-45).
enum EstadoSolicitudRol { pendiente, aprobada, rechazada, revocada }

/// User participation role for donation history filters (CU-38, CU-39).
enum PapelDonacion { donante, donatario }

/// Internal notification categories (CU-18, CU-23..CU-45).
enum TipoNotificacion {
  nuevaCoincidencia,
  nuevaPropuesta,
  propuestaAceptada,
  propuestaRechazada,
  cambioEstadoDonacion,
  decisionRolIntermediario,
  nuevoMensaje,
}

/// Approximate location limited to neighborhood or postal code (RNF-09).
class UbicacionMock {
  /// Display label (colonia or CP, never exact street address).
  final String etiqueta;
  final String? codigoPostal;

  /// Precomputed simulated distance in kilometers from the default tenant center.
  final double distanciaKmSimulada;

  /// Approximate latitude used for proximity calculations (CU-20, CU-21).
  final double latitud;

  /// Approximate longitude used for proximity calculations (CU-20, CU-21).
  final double longitud;

  const UbicacionMock({
    required this.etiqueta,
    this.codigoPostal,
    this.distanciaKmSimulada = 2.4,
    this.latitud = 19.0414,
    this.longitud = -98.2063,
  });

  /// Returns the Haversine distance in kilometers to [other], rounded to 1 decimal.
  double distanceKmTo(UbicacionMock other) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(other.latitud - latitud);
    final dLon = _degToRad(other.longitud - longitud);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(latitud)) *
            math.cos(_degToRad(other.latitud)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return double.parse((earthRadiusKm * c).toStringAsFixed(1));
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  UbicacionMock copyWith({
    String? etiqueta,
    double? distanciaKmSimulada,
    double? latitud,
    double? longitud,
  }) {
    return UbicacionMock(
      etiqueta: etiqueta ?? this.etiqueta,
      codigoPostal: codigoPostal,
      distanciaKmSimulada: distanciaKmSimulada ?? this.distanciaKmSimulada,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
    );
  }
}

/// Registered community user and derived Trust Profile metrics (CU-01 to CU-10).
class UsuarioMock {
  final String id;
  final String nombreUsuario;
  final String nombreLegal;
  final String correo;
  final String telefono;
  final String? fotoPerfil;
  final UbicacionMock ubicacionAproximada;
  final bool avisoPrivacidadAceptado;
  final bool correoVerificado;
  final bool perfilConfianzaOtorgado;
  final double promedioCalificacion;
  final int donacionesFinalizadas;
  final int numeroResenas;
  final bool telefonoCompartido;
  final bool esAdministrador;
  final bool esIntermediario;
  final DateTime? fechaRegistro;

  const UsuarioMock({
    required this.id,
    required this.nombreUsuario,
    required this.nombreLegal,
    required this.correo,
    required this.telefono,
    this.fotoPerfil,
    required this.ubicacionAproximada,
    required this.avisoPrivacidadAceptado,
    required this.correoVerificado,
    required this.perfilConfianzaOtorgado,
    required this.promedioCalificacion,
    required this.donacionesFinalizadas,
    required this.numeroResenas,
    this.telefonoCompartido = false,
    this.esAdministrador = false,
    this.esIntermediario = false,
    this.fechaRegistro,
  });

  /// Finalized donations still needed to earn the Trust Profile (CU-04).
  int get faltantesDonaciones => (5 - donacionesFinalizadas).clamp(0, 5);

  /// Reviews still needed to earn the Trust Profile (CU-04).
  int get faltantesResenas => (3 - numeroResenas).clamp(0, 3);

  /// Rating gap to reach the 4.0 Trust Profile threshold (CU-04).
  double get faltantePromedio => promedioCalificacion >= 4.0
      ? 0.0
      : double.parse((4.0 - promedioCalificacion).toStringAsFixed(1));

  UsuarioMock copyWith({
    String? id,
    String? nombreUsuario,
    String? nombreLegal,
    String? correo,
    String? telefono,
    String? fotoPerfil,
    bool clearFotoPerfil = false,
    UbicacionMock? ubicacionAproximada,
    bool? avisoPrivacidadAceptado,
    bool? correoVerificado,
    bool? perfilConfianzaOtorgado,
    double? promedioCalificacion,
    int? donacionesFinalizadas,
    int? numeroResenas,
    bool? telefonoCompartido,
    bool? esAdministrador,
    bool? esIntermediario,
    DateTime? fechaRegistro,
  }) {
    return UsuarioMock(
      id: id ?? this.id,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      nombreLegal: nombreLegal ?? this.nombreLegal,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      fotoPerfil: clearFotoPerfil ? null : (fotoPerfil ?? this.fotoPerfil),
      ubicacionAproximada: ubicacionAproximada ?? this.ubicacionAproximada,
      avisoPrivacidadAceptado:
          avisoPrivacidadAceptado ?? this.avisoPrivacidadAceptado,
      correoVerificado: correoVerificado ?? this.correoVerificado,
      perfilConfianzaOtorgado:
          perfilConfianzaOtorgado ?? this.perfilConfianzaOtorgado,
      promedioCalificacion: promedioCalificacion ?? this.promedioCalificacion,
      donacionesFinalizadas:
          donacionesFinalizadas ?? this.donacionesFinalizadas,
      numeroResenas: numeroResenas ?? this.numeroResenas,
      telefonoCompartido: telefonoCompartido ?? this.telefonoCompartido,
      esAdministrador: esAdministrador ?? this.esAdministrador,
      esIntermediario: esIntermediario ?? this.esIntermediario,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}

/// Credentials and lockout state stored with SHA-256 hash (RNF-07, CU-09).
class CuentaAccesoMock {
  final String usuarioId;
  final String passwordHash;
  final bool correoVerificado;
  final int intentosFallidos;
  final DateTime? bloqueadaHasta;

  const CuentaAccesoMock({
    required this.usuarioId,
    required this.passwordHash,
    this.correoVerificado = true,
    this.intentosFallidos = 0,
    this.bloqueadaHasta,
  });

  CuentaAccesoMock copyWith({
    String? usuarioId,
    String? passwordHash,
    bool? correoVerificado,
    int? intentosFallidos,
    DateTime? bloqueadaHasta,
    bool clearBloqueadaHasta = false,
  }) {
    return CuentaAccesoMock(
      usuarioId: usuarioId ?? this.usuarioId,
      passwordHash: passwordHash ?? this.passwordHash,
      correoVerificado: correoVerificado ?? this.correoVerificado,
      intentosFallidos: intentosFallidos ?? this.intentosFallidos,
      bloqueadaHasta: clearBloqueadaHasta
          ? null
          : (bloqueadaHasta ?? this.bloqueadaHasta),
    );
  }
}

/// Single-use, 30-minute password reset token (CU-08).
class TokenRestablecimientoMock {
  final String token;
  final String usuarioId;
  final String correo;
  final DateTime expiraEn;
  final bool usado;

  const TokenRestablecimientoMock({
    required this.token,
    required this.usuarioId,
    required this.correo,
    required this.expiraEn,
    this.usado = false,
  });

  TokenRestablecimientoMock copyWith({
    String? token,
    String? usuarioId,
    String? correo,
    DateTime? expiraEn,
    bool? usado,
  }) {
    return TokenRestablecimientoMock(
      token: token ?? this.token,
      usuarioId: usuarioId ?? this.usuarioId,
      correo: correo ?? this.correo,
      expiraEn: expiraEn ?? this.expiraEn,
      usado: usado ?? this.usado,
    );
  }
}

/// Donation publication category (CU-13, CU-48 to CU-51, RNF-14).
class CategoriaMock {
  static const alimentacionId = 'cat-alimentacion';

  final String id;
  final String nombre;
  final String iconoClave;
  final bool activa;

  const CategoriaMock({
    required this.id,
    required this.nombre,
    required this.iconoClave,
    this.activa = true,
  });

  CategoriaMock copyWith({
    String? id,
    String? nombre,
    String? iconoClave,
    bool? activa,
  }) {
    return CategoriaMock(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      iconoClave: iconoClave ?? this.iconoClave,
      activa: activa ?? this.activa,
    );
  }
}

/// Need or Item publication entity (CU-11 to CU-22, CU-46, CU-47).
class PublicacionMock {
  final String id;
  final TipoPublicacion tipo;
  final String autorId;
  final String categoriaId;
  final String titulo;
  final String descripcion;
  final EstadoPublicacion estado;
  final UbicacionMock ubicacion;
  final DateTime fechaPublicacion;
  final int cantidad;
  final CondicionArticulo? condicion;
  final Urgencia? urgencia;
  final Map<String, String> caracteristicas;
  final List<String> fotografias;
  final bool gestionadaPorIntermediario;
  final String? aliasBeneficiario;

  const PublicacionMock({
    required this.id,
    required this.tipo,
    required this.autorId,
    required this.categoriaId,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.ubicacion,
    required this.fechaPublicacion,
    required this.cantidad,
    this.condicion,
    this.urgencia,
    this.caracteristicas = const {},
    this.fotografias = const [],
    this.gestionadaPorIntermediario = false,
    this.aliasBeneficiario,
  });

  PublicacionMock copyWith({
    String? id,
    TipoPublicacion? tipo,
    String? autorId,
    String? categoriaId,
    String? titulo,
    String? descripcion,
    EstadoPublicacion? estado,
    UbicacionMock? ubicacion,
    DateTime? fechaPublicacion,
    int? cantidad,
    CondicionArticulo? condicion,
    bool clearCondicion = false,
    Urgencia? urgencia,
    bool clearUrgencia = false,
    Map<String, String>? caracteristicas,
    List<String>? fotografias,
    bool? gestionadaPorIntermediario,
    String? aliasBeneficiario,
    bool clearAliasBeneficiario = false,
  }) {
    return PublicacionMock(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      autorId: autorId ?? this.autorId,
      categoriaId: categoriaId ?? this.categoriaId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      ubicacion: ubicacion ?? this.ubicacion,
      fechaPublicacion: fechaPublicacion ?? this.fechaPublicacion,
      cantidad: cantidad ?? this.cantidad,
      condicion: clearCondicion ? null : (condicion ?? this.condicion),
      urgencia: clearUrgencia ? null : (urgencia ?? this.urgencia),
      caracteristicas: caracteristicas ?? this.caracteristicas,
      fotografias: fotografias ?? this.fotografias,
      gestionadaPorIntermediario:
          gestionadaPorIntermediario ?? this.gestionadaPorIntermediario,
      aliasBeneficiario: clearAliasBeneficiario
          ? null
          : (aliasBeneficiario ?? this.aliasBeneficiario),
    );
  }
}

/// Computed match between complementary active publications (CU-17).
class CoincidenciaMock {
  final String id;
  final String publicacionPropiaId;
  final String publicacionParId;
  final String necesidadId;
  final String articuloId;
  final String categoriaId;
  final Urgencia urgencia;
  final double? distanciaKm;
  final List<String> caracteristicasCumplidas;

  const CoincidenciaMock({
    required this.id,
    required this.publicacionPropiaId,
    required this.publicacionParId,
    required this.necesidadId,
    required this.articuloId,
    required this.categoriaId,
    required this.urgencia,
    required this.distanciaKm,
    this.caracteristicasCumplidas = const [],
  });
}

/// Request or Offer proposal sent on an active publication (CU-23 to CU-29).
class PropuestaMock {
  final String id;
  final String publicacionId;
  final String remitenteId;
  final TipoPropuesta tipo;
  final String texto;
  final List<String> fotografias;
  final EstadoPropuesta estado;
  final DateTime fechaEnvio;
  final String claveCliente;
  final String? motivoRechazo;

  const PropuestaMock({
    required this.id,
    required this.publicacionId,
    required this.remitenteId,
    required this.tipo,
    required this.texto,
    this.fotografias = const [],
    required this.estado,
    required this.fechaEnvio,
    required this.claveCliente,
    this.motivoRechazo,
  });

  PropuestaMock copyWith({
    String? id,
    String? publicacionId,
    String? remitenteId,
    TipoPropuesta? tipo,
    String? texto,
    List<String>? fotografias,
    EstadoPropuesta? estado,
    DateTime? fechaEnvio,
    String? claveCliente,
    String? motivoRechazo,
  }) {
    return PropuestaMock(
      id: id ?? this.id,
      publicacionId: publicacionId ?? this.publicacionId,
      remitenteId: remitenteId ?? this.remitenteId,
      tipo: tipo ?? this.tipo,
      texto: texto ?? this.texto,
      fotografias: fotografias ?? this.fotografias,
      estado: estado ?? this.estado,
      fechaEnvio: fechaEnvio ?? this.fechaEnvio,
      claveCliente: claveCliente ?? this.claveCliente,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
    );
  }
}

/// Immutable audit entry for donation state transitions (RNF-15, CU-35).
class CambioEstadoMock {
  final EstadoDonacion? estadoAnterior;
  final EstadoDonacion estadoNuevo;
  final DateTime fechaHora;

  /// User ID of the actor, or `null` when performed automatically by the System.
  final String? actorId;
  final String? nota;

  const CambioEstadoMock({
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.fechaHora,
    this.actorId,
    this.nota,
  });
}

/// Chat message exchanged within an active donation (CU-31).
class MensajeMock {
  final String id;
  final String donacionId;
  final String remitenteId;
  final String contenido;
  final DateTime fechaHora;

  const MensajeMock({
    required this.id,
    required this.donacionId,
    required this.remitenteId,
    required this.contenido,
    required this.fechaHora,
  });
}

/// Donation coordination, tracking, and lifecycle record (CU-28 to CU-39).
class DonacionMock {
  final String id;
  final String publicacionId;
  final String propuestaId;
  final String donanteId;
  final String donatarioId;
  final String? intermediarioId;
  final EstadoDonacion estado;
  final String? lugarEntrega;
  final DateTime? fechaEntregaAcordada;
  final DateTime? fechaEntregada;
  final DateTime? fechaFinalizacion;
  final String? motivoCancelacion;
  final bool telefonoDonanteCompartido;
  final bool telefonoDonatarioCompartido;
  final List<CambioEstadoMock> historialCambios;
  final List<MensajeMock> mensajes;

  const DonacionMock({
    required this.id,
    required this.publicacionId,
    required this.propuestaId,
    required this.donanteId,
    required this.donatarioId,
    this.intermediarioId,
    required this.estado,
    this.lugarEntrega,
    this.fechaEntregaAcordada,
    this.fechaEntregada,
    this.fechaFinalizacion,
    this.motivoCancelacion,
    this.telefonoDonanteCompartido = false,
    this.telefonoDonatarioCompartido = false,
    this.historialCambios = const [],
    this.mensajes = const [],
  });

  /// Chat is active only while coordinating delivery (CU-31, CU-36).
  bool get chatDisponible =>
      estado == EstadoDonacion.aceptada || estado == EstadoDonacion.enEntrega;

  DonacionMock copyWith({
    String? id,
    String? publicacionId,
    String? propuestaId,
    String? donanteId,
    String? donatarioId,
    String? intermediarioId,
    EstadoDonacion? estado,
    String? lugarEntrega,
    DateTime? fechaEntregaAcordada,
    DateTime? fechaEntregada,
    DateTime? fechaFinalizacion,
    String? motivoCancelacion,
    bool? telefonoDonanteCompartido,
    bool? telefonoDonatarioCompartido,
    List<CambioEstadoMock>? historialCambios,
    List<MensajeMock>? mensajes,
  }) {
    return DonacionMock(
      id: id ?? this.id,
      publicacionId: publicacionId ?? this.publicacionId,
      propuestaId: propuestaId ?? this.propuestaId,
      donanteId: donanteId ?? this.donanteId,
      donatarioId: donatarioId ?? this.donatarioId,
      intermediarioId: intermediarioId ?? this.intermediarioId,
      estado: estado ?? this.estado,
      lugarEntrega: lugarEntrega ?? this.lugarEntrega,
      fechaEntregaAcordada: fechaEntregaAcordada ?? this.fechaEntregaAcordada,
      fechaEntregada: fechaEntregada ?? this.fechaEntregada,
      fechaFinalizacion: fechaFinalizacion ?? this.fechaFinalizacion,
      motivoCancelacion: motivoCancelacion ?? this.motivoCancelacion,
      telefonoDonanteCompartido:
          telefonoDonanteCompartido ?? this.telefonoDonanteCompartido,
      telefonoDonatarioCompartido:
          telefonoDonatarioCompartido ?? this.telefonoDonatarioCompartido,
      historialCambios: historialCambios ?? this.historialCambios,
      mensajes: mensajes ?? this.mensajes,
    );
  }
}

/// Verified review left after a finalized donation (CU-05, CU-37).
class ResenaMock {
  final String id;
  final String donacionId;
  final String autorId;
  final String resenadoId;
  final int calificacion;
  final String? comentario;
  final DateTime fecha;
  final bool verificada;

  const ResenaMock({
    required this.id,
    required this.donacionId,
    required this.autorId,
    required this.resenadoId,
    required this.calificacion,
    this.comentario,
    required this.fecha,
    this.verificada = true,
  });
}

/// Community intermediary role request and admin decision record (CU-40 to CU-45).
class SolicitudRolIntermediarioMock {
  final String id;
  final String usuarioId;
  final String organizacion;
  final String documentoNombre;
  final int documentoBytesSimulados;
  final EstadoSolicitudRol estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaDecision;
  final String? revisadaPorAdminId;
  final String? motivoDecision;

  const SolicitudRolIntermediarioMock({
    required this.id,
    required this.usuarioId,
    required this.organizacion,
    required this.documentoNombre,
    required this.documentoBytesSimulados,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaDecision,
    this.revisadaPorAdminId,
    this.motivoDecision,
  });

  SolicitudRolIntermediarioMock copyWith({
    String? id,
    String? usuarioId,
    String? organizacion,
    String? documentoNombre,
    int? documentoBytesSimulados,
    EstadoSolicitudRol? estado,
    DateTime? fechaSolicitud,
    DateTime? fechaDecision,
    String? revisadaPorAdminId,
    String? motivoDecision,
  }) {
    return SolicitudRolIntermediarioMock(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      organizacion: organizacion ?? this.organizacion,
      documentoNombre: documentoNombre ?? this.documentoNombre,
      documentoBytesSimulados:
          documentoBytesSimulados ?? this.documentoBytesSimulados,
      estado: estado ?? this.estado,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      fechaDecision: fechaDecision ?? this.fechaDecision,
      revisadaPorAdminId: revisadaPorAdminId ?? this.revisadaPorAdminId,
      motivoDecision: motivoDecision ?? this.motivoDecision,
    );
  }
}

/// Internal notification sent to a user (CU-18, proposals, donations, roles).
class NotificacionMock {
  final String id;
  final String destinatarioId;
  final String publicacionId;
  final String mensaje;
  final DateTime fecha;
  final TipoNotificacion tipo;
  final bool leida;
  final String? donacionId;

  const NotificacionMock({
    required this.id,
    required this.destinatarioId,
    required this.publicacionId,
    required this.mensaje,
    required this.fecha,
    this.tipo = TipoNotificacion.nuevaPropuesta,
    this.leida = false,
    this.donacionId,
  });

  NotificacionMock copyWith({
    String? id,
    String? destinatarioId,
    String? publicacionId,
    String? mensaje,
    DateTime? fecha,
    TipoNotificacion? tipo,
    bool? leida,
    String? donacionId,
  }) {
    return NotificacionMock(
      id: id ?? this.id,
      destinatarioId: destinatarioId ?? this.destinatarioId,
      publicacionId: publicacionId ?? this.publicacionId,
      mensaje: mensaje ?? this.mensaje,
      fecha: fecha ?? this.fecha,
      tipo: tipo ?? this.tipo,
      leida: leida ?? this.leida,
      donacionId: donacionId ?? this.donacionId,
    );
  }
}
