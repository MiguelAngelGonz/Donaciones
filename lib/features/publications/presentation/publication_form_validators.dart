import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';

bool isValidExpirationDate(String value) => parseExpirationDate(value) != null;

DateTime? parseExpirationDate(String value) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
  if (match == null) return null;

  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (year < 1 || date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Validation result for Need creation and editing forms (CU-11, CU-12, CU-13, CU-15, CU-47).
class NeedValidationErrors {
  final String? tituloError;
  final String? descripcionError;
  final String? categoriaError;
  final String? cantidadError;
  final String? urgenciaError;
  final String? ubicacionError;
  final String? aliasError;

  const NeedValidationErrors({
    this.tituloError,
    this.descripcionError,
    this.categoriaError,
    this.cantidadError,
    this.urgenciaError,
    this.ubicacionError,
    this.aliasError,
  });

  bool get hasErrors =>
      tituloError != null ||
      descripcionError != null ||
      categoriaError != null ||
      cantidadError != null ||
      urgenciaError != null ||
      ubicacionError != null ||
      aliasError != null;
}

/// Validates Need fields uniformly for creation and editing.
NeedValidationErrors validateNeedFields({
  required MockTenantStore store,
  required String titulo,
  required String descripcion,
  required String? categoriaId,
  required int cantidadRequerida,
  required Urgencia? urgencia,
  required String ubicacionEtiqueta,
  required bool gestionadaPorIntermediario,
  required String aliasBeneficiario,
}) {
  final activeCategories = store.getActiveCategories();
  final hasActiveCategory =
      categoriaId != null && activeCategories.any((c) => c.id == categoriaId);

  String? aliasError;
  if (gestionadaPorIntermediario && aliasBeneficiario.trim().isEmpty) {
    aliasError = 'El alias del beneficiario es obligatorio.';
  }

  return NeedValidationErrors(
    tituloError: titulo.trim().isEmpty
        ? 'El nombre del artículo requerido es obligatorio.'
        : null,
    descripcionError: descripcion.trim().isEmpty
        ? 'La descripción de la necesidad es obligatoria.'
        : null,
    categoriaError: hasActiveCategory
        ? null
        : 'Debes seleccionar una categoría activa.',
    cantidadError: cantidadRequerida < 1
        ? 'La cantidad requerida debe ser al menos 1.'
        : null,
    urgenciaError: urgencia == null
        ? 'Toda necesidad debe tener un nivel de urgencia (Alta, Media o Baja).'
        : null,
    ubicacionError: ubicacionEtiqueta.trim().isEmpty
        ? 'La ubicación aproximada (colonia o código postal) es obligatoria.'
        : null,
    aliasError: aliasError,
  );
}

/// Validation result for Item creation and editing forms (CU-13, CU-14, CU-16).
class ItemValidationErrors {
  final String? photosError;
  final String? tituloError;
  final String? descripcionError;
  final String? categoriaError;
  final String? cantidadError;
  final String? condicionError;
  final String? ubicacionError;

  const ItemValidationErrors({
    this.photosError,
    this.tituloError,
    this.descripcionError,
    this.categoriaError,
    this.cantidadError,
    this.condicionError,
    this.ubicacionError,
  });

  bool get hasErrors =>
      photosError != null ||
      tituloError != null ||
      descripcionError != null ||
      categoriaError != null ||
      cantidadError != null ||
      condicionError != null ||
      ubicacionError != null;
}

/// Validates Item fields uniformly for creation and editing.
ItemValidationErrors validateItemFields({
  required MockTenantStore store,
  required List<String> fotografias,
  required String titulo,
  required String descripcion,
  required String? categoriaId,
  required int cantidad,
  required CondicionArticulo? condicion,
  required String ubicacionEtiqueta,
}) {
  final activeCategories = store.getActiveCategories();
  final hasActiveCategory =
      categoriaId != null && activeCategories.any((c) => c.id == categoriaId);

  String? photosError;
  if (fotografias.isEmpty) {
    photosError = 'La primera fotografía del artículo es obligatoria.';
  } else if (fotografias.length > 5) {
    photosError = 'Máximo 5 fotografías permitidas (5/5).';
  }

  return ItemValidationErrors(
    photosError: photosError,
    tituloError: titulo.trim().isEmpty
        ? 'El nombre del artículo es obligatorio.'
        : null,
    descripcionError: descripcion.trim().isEmpty
        ? 'La descripción es obligatoria.'
        : null,
    categoriaError: hasActiveCategory
        ? null
        : 'Debes seleccionar una categoría activa.',
    cantidadError: cantidad < 1
        ? 'La cantidad disponible debe ser al menos 1.'
        : null,
    condicionError:
        categoriaId != CategoriaMock.alimentacionId && condicion == null
        ? 'Selecciona el estado físico del artículo.'
        : null,
    ubicacionError: ubicacionEtiqueta.trim().isEmpty
        ? 'La ubicación aproximada (colonia o código postal) es obligatoria.'
        : null,
  );
}
