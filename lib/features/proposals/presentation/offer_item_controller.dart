import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state for offering an item to cover a Need publication (CU-24).
class OfferItemState {
  static const Object _unset = Object();

  final List<String> fotografias;
  final String description;
  final String? photosError;
  final String? descriptionError;
  final String? submissionError;
  final bool isSubmitting;
  final PropuestaMock? submittedProposal;

  const OfferItemState({
    this.fotografias = const [],
    this.description = '',
    this.photosError,
    this.descriptionError,
    this.submissionError,
    this.isSubmitting = false,
    this.submittedProposal,
  });

  OfferItemState copyWith({
    List<String>? fotografias,
    String? description,
    Object? photosError = _unset,
    Object? descriptionError = _unset,
    Object? submissionError = _unset,
    bool? isSubmitting,
    Object? submittedProposal = _unset,
  }) {
    return OfferItemState(
      fotografias: fotografias ?? this.fotografias,
      description: description ?? this.description,
      photosError: identical(photosError, _unset)
          ? this.photosError
          : photosError as String?,
      descriptionError: identical(descriptionError, _unset)
          ? this.descriptionError
          : descriptionError as String?,
      submissionError: identical(submissionError, _unset)
          ? this.submissionError
          : submissionError as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submittedProposal: identical(submittedProposal, _unset)
          ? this.submittedProposal
          : submittedProposal as PropuestaMock?,
    );
  }
}

/// Auto-disposed family provider scoped per Need publication ID (CU-24).
final offerItemControllerProvider = StateNotifierProvider.autoDispose
    .family<OfferItemController, OfferItemState, String>(
      (ref, publicationId) => OfferItemController(
        ref.read(mockTenantStoreProvider),
        publicationId: publicationId,
      ),
    );

/// Controller handling CU-24 photo (`1..5`) + description validation and RNF-11 idempotency.
class OfferItemController extends StateNotifier<OfferItemState> {
  static int _globalAttemptSeq = 0;

  final MockTenantStore _store;
  final String publicationId;
  String? _inFlightClientKey;

  OfferItemController(this._store, {required this.publicationId})
    : super(const OfferItemState());

  bool addNextSamplePhoto() {
    if (state.fotografias.length >= 5) {
      state = state.copyWith(
        photosError: 'Máximo 5 fotografías permitidas (5/5).',
      );
      return false;
    }
    final samples = _store.getSampleItemPhotos();
    final nextPhoto = samples.firstWhere(
      (s) => !state.fotografias.contains(s),
      orElse: () => 'sample://oferta_${state.fotografias.length + 1}.jpg',
    );
    state = state.copyWith(
      fotografias: List.unmodifiable([...state.fotografias, nextPhoto]),
      photosError: null,
      submissionError: null,
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
      submissionError: null,
    );
    return true;
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= state.fotografias.length) return;
    final updated = [...state.fotografias]..removeAt(index);
    state = state.copyWith(
      fotografias: List.unmodifiable(updated),
      photosError: null,
      submissionError: null,
    );
  }

  void setDescription(String value) {
    state = state.copyWith(
      description: value,
      descriptionError: null,
      submissionError: null,
    );
  }

  /// Validates `>= 1` photo and non-empty description before submitting Offer.
  Future<PropuestaMock?> submit(String rawDescription) async {
    if (state.isSubmitting) return null;

    final trimmedDesc = rawDescription.trim();
    final photosError = state.fotografias.isEmpty
        ? 'Debes agregar al menos una fotografía del artículo ofrecido.'
        : null;
    final descriptionError = trimmedDesc.isEmpty
        ? 'La descripción del artículo ofrecido es obligatoria.'
        : null;

    if (photosError != null || descriptionError != null) {
      state = state.copyWith(
        description: rawDescription,
        photosError: photosError,
        descriptionError: descriptionError,
        submissionError: null,
      );
      return null;
    }

    final sender = _store.activeUser;
    if (sender == null) {
      state = state.copyWith(
        description: rawDescription,
        submissionError: 'Debes iniciar sesión para enviar una oferta.',
      );
      return null;
    }

    _inFlightClientKey ??=
        'off-$publicationId-${sender.id}-${++_globalAttemptSeq}-${_store.currentTime.microsecondsSinceEpoch}';

    state = state.copyWith(
      description: rawDescription,
      photosError: null,
      descriptionError: null,
      submissionError: null,
      isSubmitting: true,
    );

    try {
      final created = await _store.createOfferProposal(
        publicationId: publicationId,
        senderId: sender.id,
        description: trimmedDesc,
        photos: state.fotografias,
        clientKey: _inFlightClientKey!,
      );
      _inFlightClientKey = null;
      if (!mounted) return created;
      state = state.copyWith(
        isSubmitting: false,
        submittedProposal: created,
        submissionError: null,
      );
      return created;
    } on NetworkException catch (e) {
      if (!mounted) return null;
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return null;
    } on ValidationException catch (e) {
      _inFlightClientKey = null;
      if (!mounted) return null;
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return null;
    } on UnauthorizedActionException catch (e) {
      _inFlightClientKey = null;
      if (!mounted) return null;
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return null;
    }
  }
}
