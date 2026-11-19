import 'package:donaciones/core/models/domain_models.dart';

/// Input DTO for 3-step user registration (CU-01).
class RegisterUserInput {
  final String nombreUsuario;
  final String nombreLegal;
  final String correo;
  final String telefono;
  final String password;
  final String ubicacionEtiqueta;
  final String? fotoPerfil;
  final bool avisoPrivacidadAceptado;

  const RegisterUserInput({
    required this.nombreUsuario,
    required this.nombreLegal,
    required this.correo,
    required this.telefono,
    required this.password,
    required this.ubicacionEtiqueta,
    this.fotoPerfil,
    required this.avisoPrivacidadAceptado,
  });
}

/// Input DTO for creating or updating a Need publication (CU-11, CU-15, CU-46, CU-47).
class CreateNeedInput {
  final String titulo;
  final String descripcion;
  final String categoriaId;
  final int cantidadRequerida;
  final CondicionArticulo? condicionAceptable;
  final String detallesCaracteristicas;
  final Urgencia urgencia;
  final String ubicacionEtiqueta;
  final bool gestionadaPorIntermediario;
  final String? aliasBeneficiario;

  const CreateNeedInput({
    required this.titulo,
    required this.descripcion,
    required this.categoriaId,
    required this.cantidadRequerida,
    this.condicionAceptable,
    required this.detallesCaracteristicas,
    required this.urgencia,
    required this.ubicacionEtiqueta,
    this.gestionadaPorIntermediario = false,
    this.aliasBeneficiario,
  });
}

/// Input DTO for creating or updating an Item publication (CU-14, CU-16).
class CreateItemInput {
  final String titulo;
  final String descripcion;
  final String categoriaId;
  final List<String> fotografias;
  final int cantidad;
  final CondicionArticulo condicion;
  final String ubicacionEtiqueta;

  const CreateItemInput({
    required this.titulo,
    required this.descripcion,
    required this.categoriaId,
    required this.fotografias,
    required this.cantidad,
    required this.condicion,
    required this.ubicacionEtiqueta,
  });
}
