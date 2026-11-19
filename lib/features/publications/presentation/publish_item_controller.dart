import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/features/publications/presentation/publication_form_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for the Item publication form (CU-13, CU-14).
class PublishItemState {
  static const Object _unset = Object();

  final List<String> fotografias;
  final String titulo;
  final String descripcion;
  final String? categoriaId;
  final int cantidad;
  final CondicionArticulo? condicion;
  final String ubicacionEtiqueta;
  final String? photosError;
  final String? tituloError;
  final String? descripcionError;
  final String? categoriaError;
  final String? cantidadError;
  final String? condicionError;
  final String? ubicacionError;
  final String? submissionError;
  final bool isSubmitting;
  final PublicacionMock? publishedPublication;

  const PublishItemState({
    this.fotografias = const [],
    this.titulo = '',
    this.descripcion = '',
    this.categoriaId,
    this.cantidad = 1,
    this.condicion = CondicionArticulo.nuevo,
    this.ubicacionEtiqueta = '',
    this.photosError,
    this.tituloError,
    this.descripcionError,
    this.categoriaError,
    this.cantidadError,
    this.condicionError,
    this.ubicacionError,
    this.submissionError,
    this.isSubmitting = false,
    this.publishedPublication,
  });

  PublishItemState copyWith({
    List<String>? fotografias,
    String? titulo,
    String? descripcion,
    Object? categoriaId = _unset,
    int? cantidad,
    Object? condicion = _unset,
    String? ubicacionEtiqueta,
    Object? photosError = _unset,
    Object? tituloError = _unset,
    Object? descripcionError = _unset,
    Object? categoriaError = _unset,
    Object? cantidadError = _unset,
    Object? condicionError = _unset,
    Object? ubicacionError = _unset,
    Object? submissionError = _unset,
    bool? isSubmitting,
    Object? publishedPublication = _unset,
  }) {
    return PublishItemState(
      fotografias: fotografias ?? this.fotografias,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      categoriaId: identical(categoriaId, _unset)
          ? this.categoriaId
          : categoriaId as String?,
      cantidad: cantidad ?? this.cantidad,
      condicion: identical(condicion, _unset)
          ? this.condicion
          : condicion as CondicionArticulo?,
      ubicacionEtiqueta: ubicacionEtiqueta ?? this.ubicacionEtiqueta,
      photosError: identical(photosError, _unset)
          ? this.photosError
          : photosError as String?,
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
      condicionError: identical(condicionError, _unset)
          ? this.condicionError
          : condicionError as String?,
      ubicacionError: identical(ubicacionError, _unset)
          ? this.ubicacionError
          : ubicacionError as String?,
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

/// Auto-disposed controller managing Item creation state (CU-13, CU-14).
final publishItemControllerProvider =
    StateNotifierProvider.autoDispose<PublishItemController, PublishItemState>(
      (ref) => PublishItemController(ref.read(mockTenantStoreProvider)),
    );

class PublishItemController extends StateNotifier<PublishItemState> {
  final MockTenantStore _store;

  PublishItemController(this._store)
      : super(
          PublishItemState(
            ubicacionEtiqueta:
                _store.activeUser?.ubicacionAproximada.etiqueta ?? '',
          ),
        );

  bool addNextSamplePhoto() {
    if (state.fotografias.length >= 5) {
      state = state.copyWith(
        photosError: 'Máximo 5 fotografías permitidas (5/5).',
      );
      return false;
    }
    final samples = _store.getSampleItemPhotos();
    String nextPhoto = samples.firstWhere(
      (s) => !state.fotografias.contains(s),
      orElse: () => 'sample://articulo_${state.fotografias.length + 1}.jpg',
    );
    state = state.copyWith(
      fotografias: List.unmodifiable([...state.fotografias, nextPhoto]),
      photosError: null,
    );
    return true;
  }

  bool addPhoto(String path) {
    if (state.fotografias.length >= 5) {
      state = state.copyWith(
        photosError: 'Máximo 5 fotografías permitidas (5/5).',
      );
      return false;
    }
    state = state.copyWith(
      fotografias: List.unmodifiable([...state.fotografias, path]),
      photosError: null,
    );
    return true;
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= state.fotografias.length) return;
    final updated = [...state.fotografias]..removeAt(index);
    state = state.copyWith(
      fotografias: List.unmodifiable(updated),
      photosError: null,
    );
  }

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
      cantidad: parsed,
      cantidadError: parsed >= 1
          ? null
          : 'La cantidad disponible debe ser al menos 1.',
    );
  }

  void setCondicion(CondicionArticulo condicion) {
    state = state.copyWith(condicion: condicion, condicionError: null);
  }

  void setUbicacionEtiqueta(String value) {
    state = state.copyWith(ubicacionEtiqueta: value, ubicacionError: null);
  }

  Future<PublicacionMock?> submit({
    required String titulo,
    required String descripcion,
    required String cantidadText,
    required String ubicacion,
  }) async {
    if (state.isSubmitting) return null;

    final cantidad = int.tryParse(cantidadText.trim()) ?? 0;
    final validation = validateItemFields(
      store: _store,
      fotografias: state.fotografias,
      titulo: titulo,
      descripcion: descripcion,
      categoriaId: state.categoriaId,
      cantidad: cantidad,
      condicion: state.condicion,
      ubicacionEtiqueta: ubicacion,
    );

    if (validation.hasErrors) {
      state = state.copyWith(
        titulo: titulo,
        descripcion: descripcion,
        cantidad: cantidad,
        ubicacionEtiqueta: ubicacion,
        photosError: validation.photosError,
        tituloError: validation.tituloError,
        descripcionError: validation.descripcionError,
        categoriaError: validation.categoriaError,
        cantidadError: validation.cantidadError,
        condicionError: validation.condicionError,
        ubicacionError: validation.ubicacionError,
        submissionError: null,
        publishedPublication: null,
      );
      return null;
    }

    state = state.copyWith(
      titulo: titulo,
      descripcion: descripcion,
      cantidad: cantidad,
      ubicacionEtiqueta: ubicacion,
      photosError: null,
      tituloError: null,
      descripcionError: null,
      categoriaError: null,
      cantidadError: null,
      condicionError: null,
      ubicacionError: null,
      submissionError: null,
      isSubmitting: true,
      publishedPublication: null,
    );

    try {
      final created = await _store.createItemPublication(
        CreateItemInput(
          titulo: titulo,
          descripcion: descripcion,
          categoriaId: state.categoriaId!,
          fotografias: state.fotografias,
          cantidad: cantidad,
          condicion: state.condicion!,
          ubicacionEtiqueta: ubicacion,
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
