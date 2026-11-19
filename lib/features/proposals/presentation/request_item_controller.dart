import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state for requesting an Item publication (CU-23).
class RequestItemState {
  static const Object _unset = Object();

  final String message;
  final String? messageError;
  final String? submissionError;
  final bool isSubmitting;
  final PropuestaMock? submittedProposal;

  const RequestItemState({
    this.message = '',
    this.messageError,
    this.submissionError,
    this.isSubmitting = false,
    this.submittedProposal,
  });

  RequestItemState copyWith({
    String? message,
    Object? messageError = _unset,
    Object? submissionError = _unset,
    bool? isSubmitting,
    Object? submittedProposal = _unset,
  }) {
    return RequestItemState(
      message: message ?? this.message,
      messageError: identical(messageError, _unset)
          ? this.messageError
          : messageError as String?,
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

/// Auto-disposed family provider scoped per publication ID (CU-23).
final requestItemControllerProvider = StateNotifierProvider.autoDispose
    .family<RequestItemController, RequestItemState, String>(
      (ref, publicationId) => RequestItemController(
        ref.read(mockTenantStoreProvider),
        publicationId: publicationId,
      ),
    );

/// Controller handling CU-23 validation, RNF-11 idempotency, and error handling.
class RequestItemController extends StateNotifier<RequestItemState> {
  static int _globalAttemptSeq = 0;

  final MockTenantStore _store;
  final String publicationId;
  String? _inFlightClientKey;

  RequestItemController(this._store, {required this.publicationId})
    : super(const RequestItemState());

  void setMessage(String value) {
    final trimmedLen = value.trim().length;
    state = state.copyWith(
      message: value,
      messageError: trimmedLen > 300
          ? 'El mensaje debe tener máximo 300 caracteres.'
          : null,
      submissionError: null,
    );
  }

  /// Validates and submits a Request proposal (`1..300` chars) to [MockTenantStore].
  Future<PropuestaMock?> submit(String rawMessage) async {
    if (state.isSubmitting) return null;

    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        message: rawMessage,
        messageError:
            'Ingresa un mensaje para el donante (mínimo 1 y máximo 300 caracteres).',
        submissionError: null,
      );
      return null;
    }
    if (trimmed.length > 300) {
      state = state.copyWith(
        message: rawMessage,
        messageError: 'El mensaje debe tener máximo 300 caracteres.',
        submissionError: null,
      );
      return null;
    }

    final sender = _store.activeUser;
    if (sender == null) {
      state = state.copyWith(
        message: rawMessage,
        submissionError: 'Debes iniciar sesión para enviar una solicitud.',
      );
      return null;
    }

    _inFlightClientKey ??=
        'req-$publicationId-${sender.id}-${++_globalAttemptSeq}-${_store.currentTime.microsecondsSinceEpoch}';

    state = state.copyWith(
      message: rawMessage,
      messageError: null,
      submissionError: null,
      isSubmitting: true,
    );

    try {
      final created = await _store.createRequestProposal(
        publicationId: publicationId,
        senderId: sender.id,
        message: trimmed,
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
