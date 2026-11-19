import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/features/publications/presentation/publication_form_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for the Need publication form (CU-11, CU-12, CU-13, CU-46, CU-47).
class PublishNeedState {
  static const Object _unset = Object();

  final String titulo;
  final String descripcion;
  final String? categoriaId;
  final int cantidadRequerida;
  final CondicionArticulo? condicionAceptable;
  final String detallesCaracteristicas;
  final Urgencia? urgencia;
  final String ubicacionEtiqueta;
  final bool gestionadaPorIntermediario;
  final String aliasBeneficiario;
  final String? tituloError;
  final String? descripcionError;
  final String? categoriaError;
  final String? cantidadError;
  final String? urgenciaError;
  final String? ubicacionError;
  final String? aliasError;
  final String? submissionError;
  final bool isSubmitting;
  final PublicacionMock? publishedPublication;

  const PublishNeedState({
    this.titulo = '',
    this.descripcion = '',
    this.categoriaId,
    this.cantidadRequerida = 1,
    this.condicionAceptable,
    this.detallesCaracteristicas = '',
    this.urgencia,
    this.ubicacionEtiqueta = '',
    this.gestionadaPorIntermediario = false,
    this.aliasBeneficiario = '',
    this.tituloError,
    this.descripcionError,
    this.categoriaError,
    this.cantidadError,
    this.urgenciaError,
    this.ubicacionError,
    this.aliasError,
    this.submissionError,
    this.isSubmitting = false,
    this.publishedPublication,
  });

  PublishNeedState copyWith({
    String? titulo,
    String? descripcion,
    Object? categoriaId = _unset,
    int? cantidadRequerida,
    Object? condicionAceptable = _unset,
    String? detallesCaracteristicas,
    Object? urgencia = _unset,
    String? ubicacionEtiqueta,
    bool? gestionadaPorIntermediario,
    String? aliasBeneficiario,
    Object? tituloError = _unset,
    Object? descripcionError = _unset,
    Object? categoriaError = _unset,
    Object? cantidadError = _unset,
    Object? urgenciaError = _unset,
    Object? ubicacionError = _unset,
    Object? aliasError = _unset,
    Object? submissionError = _unset,
    bool? isSubmitting,
    Object? publishedPublication = _unset,
  }) {
    return PublishNeedState(
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      categoriaId: identical(categoriaId, _unset)
          ? this.categoriaId
          : categoriaId as String?,
      cantidadRequerida: cantidadRequerida ?? this.cantidadRequerida,
      condicionAceptable: identical(condicionAceptable, _unset)
          ? this.condicionAceptable
          : condicionAceptable as CondicionArticulo?,
      detallesCaracteristicas:
          detallesCaracteristicas ?? this.detallesCaracteristicas,
      urgencia: identical(urgencia, _unset)
          ? this.urgencia
          : urgencia as Urgencia?,
      ubicacionEtiqueta: ubicacionEtiqueta ?? this.ubicacionEtiqueta,
      gestionadaPorIntermediario:
          gestionadaPorIntermediario ?? this.gestionadaPorIntermediario,
      aliasBeneficiario: aliasBeneficiario ?? this.aliasBeneficiario,
      tituloError: identical(tituloError, _unset)
          ? this.tituloError
          : tituloError as String?,
      descripcionError: identical(descripcionError, _unset)
          ? this.descripcionError
          : descripcionError as String?,
      categoriaError: identical(categoriaError, _unset)
          ? this.categoriaError
          : categoriaError as String?,
      cantidadError: identical(cantidadError, _unset)
          ? this.cantidadError
          : cantidadError as String?,
      urgenciaError: identical(urgenciaError, _unset)
          ? this.urgenciaError
          : urgenciaError as String?,
      ubicacionError: identical(ubicacionError, _unset)
          ? this.ubicacionError
          : ubicacionError as String?,
      aliasError: identical(aliasError, _unset)
          ? this.aliasError
          : aliasError as String?,
      submissionError: identical(submissionError, _unset)
          ? this.submissionError
          : submissionError as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      publishedPublication: identical(publishedPublication, _unset)
          ? this.publishedPublication
          : publishedPublication as PublicacionMock?,
    );
  }
}

/// Auto-disposed controller managing Need creation state (CU-11..13, CU-46..47).
final publishNeedControllerProvider =
    StateNotifierProvider.autoDispose<PublishNeedController, PublishNeedState>(
      (ref) => PublishNeedController(ref.read(mockTenantStoreProvider)),
    );

class PublishNeedController extends StateNotifier<PublishNeedState> {
  final MockTenantStore _store;

  PublishNeedController(this._store)
      : super(
          PublishNeedState(
            ubicacionEtiqueta:
                _store.activeUser?.ubicacionAproximada.etiqueta ?? '',
          ),
        );

  void setTitulo(String value) {
    state = state.copyWith(titulo: value, tituloError: null);
  }

  void setDescripcion(String value) {
    state = state.copyWith(descripcion: value, descripcionError: null);
  }

  void setCategoriaId(String? categoryId) {
    state = state.copyWith(categoriaId: categoryId, categoriaError: null);
  }

  void setCantidadFromText(String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    state = state.copyWith(
      cantidadRequerida: parsed,
      cantidadError: parsed >= 1
          ? null
          : 'La cantidad requerida debe ser al menos 1.',
    );
  }

  void setCondicionAceptable(CondicionArticulo? condition) {
    state = state.copyWith(condicionAceptable: condition);
  }

  void setDetallesCaracteristicas(String value) {
    state = state.copyWith(detallesCaracteristicas: value);
  }

  void setUrgencia(Urgencia urgencia) {
    state = state.copyWith(urgencia: urgencia, urgenciaError: null);
  }

  void setUbicacionEtiqueta(String value) {
    state = state.copyWith(ubicacionEtiqueta: value, ubicacionError: null);
  }

  void setGestionadaPorIntermediario(bool enabled) {
    state = state.copyWith(
      gestionadaPorIntermediario: enabled,
      aliasError: enabled ? state.aliasError : null,
    );
  }

  void setAliasBeneficiario(String value) {
    state = state.copyWith(aliasBeneficiario: value, aliasError: null);
  }

  Future<PublicacionMock?> submit({
    required String titulo,
    required String descripcion,
    required String cantidadText,
    required String detalles,
    required String ubicacion,
    required String aliasBeneficiario,
  }) async {
    if (state.isSubmitting) return null;

    final cantidad = int.tryParse(cantidadText.trim()) ?? 0;
    final canManageIntermediary = _store.activeUser?.esIntermediario == true;
    final effectiveIntermediary =
        canManageIntermediary && state.gestionadaPorIntermediario;

    final validation = validateNeedFields(
      store: _store,
      titulo: titulo,
      descripcion: descripcion,
      categoriaId: state.categoriaId,
      cantidadRequerida: cantidad,
      urgencia: state.urgencia,
      ubicacionEtiqueta: ubicacion,
      gestionadaPorIntermediario: effectiveIntermediary,
      aliasBeneficiario: aliasBeneficiario,
    );

    if (validation.hasErrors) {
      state = state.copyWith(
        titulo: titulo,
        descripcion: descripcion,
        cantidadRequerida: cantidad,
        detallesCaracteristicas: detalles,
        ubicacionEtiqueta: ubicacion,
        gestionadaPorIntermediario: effectiveIntermediary,
        aliasBeneficiario: aliasBeneficiario,
        tituloError: validation.tituloError,
        descripcionError: validation.descripcionError,
        categoriaError: validation.categoriaError,
        cantidadError: validation.cantidadError,
        urgenciaError: validation.urgenciaError,
        ubicacionError: validation.ubicacionError,
        aliasError: validation.aliasError,
        submissionError: null,
        publishedPublication: null,
      );
      return null;
    }

    state = state.copyWith(
      titulo: titulo,
      descripcion: descripcion,
      cantidadRequerida: cantidad,
      detallesCaracteristicas: detalles,
      ubicacionEtiqueta: ubicacion,
      gestionadaPorIntermediario: effectiveIntermediary,
      aliasBeneficiario: aliasBeneficiario,
      tituloError: null,
      descripcionError: null,
      categoriaError: null,
      cantidadError: null,
      urgenciaError: null,
      ubicacionError: null,
      aliasError: null,
      submissionError: null,
      isSubmitting: true,
      publishedPublication: null,
    );

    try {
      final created = await _store.createNeedPublication(
        CreateNeedInput(
          titulo: titulo,
          descripcion: descripcion,
          categoriaId: state.categoriaId!,
          cantidadRequerida: cantidad,
          condicionAceptable: state.condicionAceptable,
          detallesCaracteristicas: detalles,
          urgencia: state.urgencia!,
          ubicacionEtiqueta: ubicacion,
          gestionadaPorIntermediario: effectiveIntermediary,
          aliasBeneficiario: effectiveIntermediary ? aliasBeneficiario : null,
        ),
      );
      state = state.copyWith(
        isSubmitting: false,
        publishedPublication: created,
        submissionError: null,
      );
      return created;
    } on NetworkException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submissionError: e.message,
        publishedPublication: null,
      );
      return null;
    } on ValidationException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submissionError: e.message,
        publishedPublication: null,
      );
      return null;
    } on UnauthorizedActionException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submissionError: e.message,
        publishedPublication: null,
      );
      return null;
    }
  }
}
