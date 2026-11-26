import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/features/donations/presentation/donation_ui_helpers.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Detailed tracking, coordination chat, phone privacy, reviews, and history (CU-30..CU-37).
class DonationTrackingScreen extends ConsumerStatefulWidget {
  final String donationId;

  const DonationTrackingScreen({super.key, required this.donationId});

  @override
  ConsumerState<DonationTrackingScreen> createState() =>
      _DonationTrackingScreenState();
}

class _DonationTrackingScreenState
    extends ConsumerState<DonationTrackingScreen> {
  final _placeController = TextEditingController();
  final _chatController = TextEditingController();
  final _reviewCommentController = TextEditingController();
  final _pendingActionKeys = PendingActionKeys();

  DateTime? _selectedDeliveryDate;
  String? _placeError;
  String? _chatError;
  String? _reviewError;
  String? _actionError;

  bool _isProcessingAction = false;
  bool _isSendingMessage = false;
  bool _isSubmittingReview = false;
  int _selectedRating = 0;

  @override
  void didUpdateWidget(covariant DonationTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.donationId != widget.donationId) {
      _placeController.clear();
      _chatController.clear();
      _reviewCommentController.clear();
      _pendingActionKeys.clearAll();
      _selectedDeliveryDate = null;
      _placeError = null;
      _chatError = null;
      _reviewError = null;
      _actionError = null;
      _isProcessingAction = false;
      _isSendingMessage = false;
      _isSubmittingReview = false;
      _selectedRating = 0;
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    _chatController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  void _navigateBack() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/donations');
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  DateTime _resolveDeliveryDate(MockTenantStore store) {
    final firstDate = store.currentTime.subtract(const Duration(days: 1));
    final lastDate = store.currentTime.add(const Duration(days: 180));
    final fallback = store.currentTime.add(const Duration(days: 1));
    final selected = _selectedDeliveryDate;
    if (selected == null || selected.isBefore(firstDate)) {
      return fallback;
    }
    if (selected.isAfter(lastDate)) {
      return lastDate;
    }
    return selected;
  }

  Future<void> _pickDeliveryDate(MockTenantStore store) async {
    final firstDay = DateUtils.dateOnly(
      store.currentTime.subtract(const Duration(days: 1)),
    );
    final lastDay = DateUtils.dateOnly(
      store.currentTime.add(const Duration(days: 180)),
    );
    final resolved = _resolveDeliveryDate(store);
    final resolvedDay = DateUtils.dateOnly(resolved);
    final DateTime initialDate;
    if (resolvedDay.isBefore(firstDay)) {
      initialDate = DateUtils.dateOnly(
        store.currentTime.add(const Duration(days: 1)),
      );
    } else if (resolvedDay.isAfter(lastDay)) {
      initialDate = lastDay;
    } else {
      initialDate = resolvedDay;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDay,
      lastDate: lastDay,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDeliveryDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        store.currentTime.hour,
        store.currentTime.minute,
      );
    });
  }

  Future<void> _runDonationAction(
    Future<void> Function(String clientKey) action, {
    required String operationKey,
    required String successMessage,
  }) async {
    if (_isProcessingAction) return;
    final store = ref.read(mockTenantStoreProvider);
    final clientKey = _pendingActionKeys.getOrCreate(operationKey, store);
    setState(() {
      _isProcessingAction = true;
      _actionError = null;
    });

    try {
      await action(clientKey);
      _pendingActionKeys.clear(operationKey);
      if (!mounted) return;
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on NetworkException catch (e) {
      // Retain clientKey across NetworkException so retries stay idempotent (RNF-11).
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
        _actionError = e.message;
      });
    } on ValidationException catch (e) {
      _pendingActionKeys.clear(operationKey);
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
        _actionError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      _pendingActionKeys.clear(operationKey);
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
        _actionError = e.message;
      });
    }
  }

  Future<void> _registerDeliverySchedule(DonacionMock donation) async {
    if (_isProcessingAction) return;
    final place = _placeController.text.trim();
    if (place.isEmpty) {
      setState(() {
        _placeError = 'El lugar de entrega es obligatorio.';
        _actionError = null;
      });
      return;
    }

    setState(() => _placeError = null);
    final store = ref.read(mockTenantStoreProvider);
    final scheduledDate = _resolveDeliveryDate(store);

    await _runDonationAction(
      (clientKey) => store.registerDeliverySchedule(
        donationId: donation.id,
        place: place,
        scheduledDate: scheduledDate,
        clientKey: clientKey,
      ),
      operationKey: 'sched-${donation.id}',
      successMessage:
          'Lugar y fecha acordados registrados. Estado: En entrega.',
    );
  }

  Future<void> _markDelivered(DonacionMock donation) async {
    final store = ref.read(mockTenantStoreProvider);
    await _runDonationAction(
      (clientKey) => store.markDonationDelivered(
        donationId: donation.id,
        clientKey: clientKey,
      ),
      operationKey: 'deliv-${donation.id}',
      successMessage: 'Donación marcada como Entregada.',
    );
  }

  Future<void> _confirmReceived(DonacionMock donation) async {
    final store = ref.read(mockTenantStoreProvider);
    await _runDonationAction(
      (clientKey) => store.confirmDonationReceived(
        donationId: donation.id,
        clientKey: clientKey,
      ),
      operationKey: 'conf-${donation.id}',
      successMessage: 'Recepción confirmada. ¡Donación finalizada!',
    );
  }

  Future<void> _openCancelDonationDialog(DonacionMock donation) async {
    if (_isProcessingAction) return;
    final store = ref.read(mockTenantStoreProvider);
    final opKey = 'cancel-${donation.id}';
    final cancelled = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CancelDonationDialog(
        onConfirm: (reason) async {
          final clientKey = _pendingActionKeys.getOrCreate(opKey, store);
          try {
            final result = await store.cancelDonation(
              donationId: donation.id,
              reason: reason,
              clientKey: clientKey,
            );
            _pendingActionKeys.clear(opKey);
            return result;
          } on ValidationException {
            _pendingActionKeys.clear(opKey);
            rethrow;
          } on UnauthorizedActionException {
            _pendingActionKeys.clear(opKey);
            rethrow;
          }
        },
      ),
    );

    if (cancelled == true && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Donación cancelada. La publicación volvió a estar Activa.',
          ),
        ),
      );
    }
  }

  Future<void> _togglePhoneSharing(DonacionMock donation, bool value) async {
    final store = ref.read(mockTenantStoreProvider);
    try {
      await store.toggleSharePhoneInDonation(
        donationId: donation.id,
        share: value,
      );
      if (mounted) {
        setState(() => _actionError = null);
      }
    } on NetworkException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } on ValidationException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } on UnauthorizedActionException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    }
  }

  Future<void> _sendMessage(DonacionMock donation) async {
    if (_isSendingMessage) return;
    final content = _chatController.text.trim();
    if (content.isEmpty) {
      setState(() => _chatError = 'El mensaje no puede estar vacío.');
      return;
    }

    final store = ref.read(mockTenantStoreProvider);
    setState(() {
      _isSendingMessage = true;
      _chatError = null;
      _actionError = null;
    });

    try {
      await store.sendChatMessage(donationId: donation.id, content: content);
      if (!mounted) return;
      _chatController.clear();
      setState(() => _isSendingMessage = false);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingMessage = false;
        _chatError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingMessage = false;
        _chatError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingMessage = false;
        _chatError = e.message;
      });
    }
  }

  Future<void> _submitReview(DonacionMock donation) async {
    if (_isSubmittingReview) return;
    if (_selectedRating < 1 || _selectedRating > 5) {
      setState(
        () => _reviewError = 'La calificación debe estar entre 1 y 5 estrellas.',
      );
      return;
    }
    final cleanComment = _reviewCommentController.text.trim();
    if (cleanComment.length > 500) {
      setState(
        () => _reviewError = 'El comentario no puede superar los 500 caracteres.',
      );
      return;
    }

    final store = ref.read(mockTenantStoreProvider);
    setState(() {
      _isSubmittingReview = true;
      _reviewError = null;
      _actionError = null;
    });

    try {
      await store.submitReview(
        donationId: donation.id,
        rating: _selectedRating,
        comment: cleanComment.isEmpty ? null : cleanComment,
      );
      if (!mounted) return;
      _reviewCommentController.clear();
      setState(() {
        _isSubmittingReview = false;
        _selectedRating = 0;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Reseña verificada enviada y Perfil de Confianza actualizado.',
          ),
        ),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingReview = false;
        _reviewError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingReview = false;
        _reviewError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingReview = false;
        _reviewError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final donation = store.findDonationById(widget.donationId);
    final activeUser = store.activeUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        title: const Text('Seguimiento de donación'),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: _buildBody(
              context: context,
              store: store,
              donation: donation,
              activeUser: activeUser,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required MockTenantStore store,
    required DonacionMock? donation,
    required UsuarioMock? activeUser,
  }) {
    if (donation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Donación no encontrada'),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _navigateBack,
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    if (activeUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Inicia sesión para consultar el seguimiento de esta donación.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => GoRouter.maybeOf(context)?.go('/login'),
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      );
    }

    final isParticipant =
        activeUser.id == donation.donanteId ||
        activeUser.id == donation.donatarioId ||
        activeUser.id == donation.intermediarioId;
    if (!isParticipant) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: PublicationStatusBanner(
            message:
                'Solo las partes involucradas pueden consultar los detalles de esta donación.',
            tone: PublicationBannerTone.warning,
          ),
        ),
      );
    }

    final publication = store.findPublicationById(donation.publicacionId);
    final donor = store.findUserById(donation.donanteId);
    final recipient = store.findUserById(donation.donatarioId);
    final intermediary = donation.intermediarioId == null
        ? null
        : store.findUserById(donation.intermediarioId!);
    final isDonor = activeUser.id == donation.donanteId;
    final counterpart = isDonor ? recipient : donor;
    final myPhoneShared = isDonor
        ? donation.telefonoDonanteCompartido
        : donation.telefonoDonatarioCompartido;
    final counterpartPhoneShared = isDonor
        ? donation.telefonoDonatarioCompartido
        : donation.telefonoDonanteCompartido;

    final selectedDate = _resolveDeliveryDate(store);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryCard(
                donation: donation,
                publication: publication,
                donor: donor,
                recipient: recipient,
                intermediary: intermediary,
              ),
              if (_actionError != null) ...[
                const SizedBox(height: 12),
                PublicationStatusBanner(
                  message: _actionError!,
                  tone: PublicationBannerTone.error,
                ),
              ],
              const SizedBox(height: 14),
              _buildLifecycleActionsCard(
                context: context,
                store: store,
                donation: donation,
                activeUser: activeUser,
                selectedDate: selectedDate,
              ),
              const SizedBox(height: 14),
              _buildChatCard(
                context: context,
                store: store,
                donation: donation,
                activeUser: activeUser,
                counterpart: counterpart,
                myPhoneShared: myPhoneShared,
                counterpartPhoneShared: counterpartPhoneShared,
              ),
              if (donation.estado == EstadoDonacion.finalizada) ...[
                const SizedBox(height: 14),
                _buildReviewCard(
                  context: context,
                  store: store,
                  donation: donation,
                  activeUser: activeUser,
                  counterpart: counterpart,
                ),
              ],
              const SizedBox(height: 14),
              _HistoryLogCard(
                donation: donation,
                store: store,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifecycleActionsCard({
    required BuildContext context,
    required MockTenantStore store,
    required DonacionMock donation,
    required UsuarioMock activeUser,
    required DateTime selectedDate,
  }) {
    final theme = Theme.of(context);
    final isDonor = activeUser.id == donation.donanteId;
    final isRecipientOrIntermediary =
        activeUser.id == donation.donatarioId ||
        activeUser.id == donation.intermediarioId;

    if (donation.estado == EstadoDonacion.finalizada ||
        donation.estado == EstadoDonacion.cancelada) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Acciones de la donación',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (donation.estado == EstadoDonacion.aceptada) ...[
              Text(
                'Registrar lugar y fecha de entrega (CU-32)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('delivery_place_field'),
                controller: _placeController,
                enabled: !_isProcessingAction,
                onChanged: (_) => setState(() => _placeError = null),
                decoration: InputDecoration(
                  labelText: 'Lugar de entrega acordado *',
                  hintText: 'Ej. Parque del Carmen, Puebla',
                  prefixIcon: const Icon(Icons.place_outlined),
                  errorText: _placeError,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Fecha acordada: ${formatDonationDate(selectedDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('delivery_date_picker_button'),
                    onPressed: _isProcessingAction
                        ? null
                        : () => _pickDeliveryDate(store),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: const Text('Elegir fecha'),
                  ),
                  ChoiceChip(
                    label: const Text('Mañana'),
                    selected: DateUtils.isSameDay(
                      selectedDate,
                      store.currentTime.add(const Duration(days: 1)),
                    ),
                    onSelected: _isProcessingAction
                        ? null
                        : (_) => setState(
                            () => _selectedDeliveryDate = store.currentTime.add(
                              const Duration(days: 1),
                            ),
                          ),
                  ),
                  ChoiceChip(
                    label: const Text('En 3 días'),
                    selected: DateUtils.isSameDay(
                      selectedDate,
                      store.currentTime.add(const Duration(days: 3)),
                    ),
                    onSelected: _isProcessingAction
                        ? null
                        : (_) => setState(
                            () => _selectedDeliveryDate = store.currentTime.add(
                              const Duration(days: 3),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('register_delivery_schedule_button'),
                onPressed: _isProcessingAction
                    ? null
                    : () => _registerDeliverySchedule(donation),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Registrar lugar y fecha de entrega'),
              ),
            ] else if (donation.estado == EstadoDonacion.enEntrega) ...[
              if (isDonor)
                FilledButton.icon(
                  key: const Key('mark_delivered_button'),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _markDelivered(donation),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Marcar como Entregada'),
                )
              else
                const PublicationStatusBanner(
                  message:
                      'Esperando a que el donante marque el artículo como Entregado.',
                  tone: PublicationBannerTone.info,
                ),
            ] else if (donation.estado == EstadoDonacion.entregada) ...[
              if (isRecipientOrIntermediary)
                FilledButton.icon(
                  key: const Key('confirm_received_button'),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _confirmReceived(donation),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar recepción'),
                )
              else
                const PublicationStatusBanner(
                  message:
                      'Entrega marcada. Esperando confirmación del donatario (cierre automático tras 7 días).',
                  tone: PublicationBannerTone.info,
                ),
            ],
            if (donation.estado == EstadoDonacion.aceptada ||
                donation.estado == EstadoDonacion.enEntrega) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('cancel_donation_button'),
                onPressed: _isProcessingAction
                    ? null
                    : () => _openCancelDonationDialog(donation),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar donación'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatCard({
    required BuildContext context,
    required MockTenantStore store,
    required DonacionMock donation,
    required UsuarioMock activeUser,
    required UsuarioMock? counterpart,
    required bool myPhoneShared,
    required bool counterpartPhoneShared,
  }) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;
    final phone = activeUser.telefono;
    final suffix = phone.length > 4 ? phone.substring(phone.length - 4) : '';
    final maskedPhone = suffix.padLeft(phone.length, '*');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat de coordinación (CU-31)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (donation.chatDisponible) ...[
              Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: highContrast
                        ? Colors.black
                        : DonaPlusColors.borderLight,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      key: const Key('share_phone_switch'),
                      value: myPhoneShared,
                      onChanged: (value) => _togglePhoneSharing(donation, value),
                      title: const Text('Compartir mi teléfono'),
                      subtitle: Text(
                        'Tu número ($maskedPhone) se comparte completo al activar esta opción.',
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            counterpartPhoneShared
                                ? Icons.phone_enabled_outlined
                                : Icons.privacy_tip_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (counterpartPhoneShared && counterpart != null)
                                  ? 'Teléfono de ${counterpart.nombreLegal}: ${counterpart.telefono}'
                                  : 'Teléfono oculto por privacidad (RNF-09)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const PublicationStatusBanner(
                message: 'El chat ya no está disponible para esta donación',
                tone: PublicationBannerTone.info,
              ),
              const SizedBox(height: 12),
            ],
            if (donation.mensajes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no hay mensajes en esta conversación.'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final msg in donation.mensajes) ...[
                    _ChatBubble(
                      message: msg,
                      senderName: msg.remitenteId == activeUser.id
                          ? 'Tú'
                          : (store.findUserById(msg.remitenteId)?.nombreLegal ??
                                msg.remitenteId),
                      isOwn: msg.remitenteId == activeUser.id,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            if (donation.chatDisponible) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('chat_message_field'),
                controller: _chatController,
                enabled: !_isSendingMessage,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() => _chatError = null),
                decoration: InputDecoration(
                  labelText: 'Escribe un mensaje para coordinar',
                  errorText: _chatError,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('chat_send_button'),
                  onPressed: _isSendingMessage
                      ? null
                      : () => _sendMessage(donation),
                  icon: const Icon(Icons.send),
                  label: Text(
                    _isSendingMessage ? 'Enviando...' : 'Enviar mensaje',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required BuildContext context,
    required MockTenantStore store,
    required DonacionMock donation,
    required UsuarioMock activeUser,
    required UsuarioMock? counterpart,
  }) {
    final theme = Theme.of(context);
    final alreadyReviewed = store.reviews.any(
      (r) => r.donacionId == donation.id && r.autorId == activeUser.id,
    );
    final daysElapsed = donation.fechaFinalizacion == null
        ? 999
        : store.currentTime.difference(donation.fechaFinalizacion!).inDays;
    final commentLength = _reviewCommentController.text.trim().length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.star_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reseña de la donación (CU-37)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (alreadyReviewed)
              const PublicationStatusBanner(
                message: 'Ya enviaste tu reseña para esta donación',
                tone: PublicationBannerTone.success,
              )
            else if (daysElapsed > 14)
              const PublicationStatusBanner(
                message:
                    'El plazo de 14 días para reseñar esta donación ha vencido',
                tone: PublicationBannerTone.warning,
              )
            else ...[
              Text(
                'Califica tu experiencia con ${counterpart?.nombreLegal ?? 'la otra parte'}:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      key: Key('review_star_$star'),
                      tooltip: '$star estrellas',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        star <= _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 30,
                        color: star <= _selectedRating
                            ? const Color(0xFFB26A00)
                            : theme.colorScheme.outline,
                      ),
                      onPressed: _isSubmittingReview
                          ? null
                          : () => setState(() {
                              _selectedRating = star;
                              _reviewError = null;
                            }),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedRating == 0
                        ? 'Selecciona 1 a 5 estrellas'
                        : '$_selectedRating / 5 estrellas',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('review_comment_field'),
                controller: _reviewCommentController,
                enabled: !_isSubmittingReview,
                minLines: 2,
                maxLines: 4,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                onChanged: (_) => setState(() => _reviewError = null),
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional, máx. 500 caracteres)',
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$commentLength / 500 caracteres',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: commentLength > 500
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (_reviewError != null) ...[
                const SizedBox(height: 6),
                PublicationStatusBanner(
                  message: _reviewError!,
                  tone: PublicationBannerTone.error,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('submit_review_button'),
                onPressed: _isSubmittingReview
                    ? null
                    : () => _submitReview(donation),
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(
                  _isSubmittingReview ? 'Enviando...' : 'Enviar reseña',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DonacionMock donation;
  final PublicacionMock? publication;
  final UsuarioMock? donor;
  final UsuarioMock? recipient;
  final UsuarioMock? intermediary;

  const _SummaryCard({
    required this.donation,
    required this.publication,
    required this.donor,
    required this.recipient,
    required this.intermediary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DonationStatusBadge(estado: donation.estado),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('ID: ${donation.id}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              publication?.titulo ?? 'Donación ${donation.id}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            DonationProgressTimeline(estado: donation.estado),
            const Divider(height: 22),
            Text(
              'Donante: ${donor?.nombreLegal ?? donation.donanteId} (@${donor?.nombreUsuario ?? '-'})',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Donatario: ${recipient?.nombreLegal ?? donation.donatarioId} (@${recipient?.nombreUsuario ?? '-'})',
              style: theme.textTheme.bodyMedium,
            ),
            if (intermediary != null) ...[
              const SizedBox(height: 4),
              Text(
                'Intermediario: ${intermediary!.nombreLegal}'
                '${publication?.aliasBeneficiario != null ? ' · Beneficiario: ${publication!.aliasBeneficiario}' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (donation.lugarEntrega != null &&
                donation.fechaEntregaAcordada != null) ...[
              const SizedBox(height: 10),
              PublicationStatusBanner(
                message:
                    'Entrega acordada: ${donation.lugarEntrega} (${formatDonationDateTime(donation.fechaEntregaAcordada!)})',
                tone: PublicationBannerTone.info,
              ),
            ],
            if (donation.estado == EstadoDonacion.cancelada &&
                donation.motivoCancelacion != null) ...[
              const SizedBox(height: 10),
              PublicationStatusBanner(
                message:
                    'Motivo de cancelación: ${donation.motivoCancelacion}',
                tone: PublicationBannerTone.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MensajeMock message;
  final String senderName;
  final bool isOwn;

  const _ChatBubble({
    required this.message,
    required this.senderName,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOwn
            ? (highContrast
                  ? DonaPlusColors.accentMint
                  : DonaPlusColors.accentMint.withValues(alpha: 0.35))
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highContrast ? Colors.black : DonaPlusColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              Text(
                senderName,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatDonationDateTime(message.fechaHora),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.contenido, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HistoryLogCard extends StatelessWidget {
  final DonacionMock donation;
  final MockTenantStore store;

  const _HistoryLogCard({required this.donation, required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Historial de cambios (CU-35)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < donation.historialCambios.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _HistoryEntryRow(
                entry: donation.historialCambios[i],
                actorName: donation.historialCambios[i].actorId == null
                    ? 'Sistema'
                    : (store
                              .findUserById(
                                donation.historialCambios[i].actorId!,
                              )
                              ?.nombreLegal ??
                          donation.historialCambios[i].actorId!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryEntryRow extends StatelessWidget {
  final CambioEstadoMock entry;
  final String actorName;

  const _HistoryEntryRow({required this.entry, required this.actorName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transition = entry.estadoAnterior == null
        ? 'Inicio → ${labelForEstadoDonacion(entry.estadoNuevo)}'
        : '${labelForEstadoDonacion(entry.estadoAnterior!)} → ${labelForEstadoDonacion(entry.estadoNuevo)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          transition,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Por: $actorName · ${formatDonationDateTime(entry.fechaHora)}',
          style: theme.textTheme.bodySmall,
        ),
        if (entry.nota != null && entry.nota!.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(entry.nota!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _CancelDonationDialog extends StatefulWidget {
  final Future<DonacionMock> Function(String reason) onConfirm;

  const _CancelDonationDialog({required this.onConfirm});

  @override
  State<_CancelDonationDialog> createState() => _CancelDonationDialogState();
}

class _CancelDonationDialogState extends State<_CancelDonationDialog> {
  final _reasonController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_isSubmitting) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorText = 'Debes indicar el motivo de la cancelación.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.onConfirm(reason);
      if (mounted) Navigator.of(context).pop(true);
    } on NetworkException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = e.message;
        });
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = e.message;
        });
      }
    } on UnauthorizedActionException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar donación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Al cancelar, la publicación volverá a estado Activa y el chat se cerrará.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cancel_donation_reason_field'),
            controller: _reasonController,
            enabled: !_isSubmitting,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() => _errorText = null),
            decoration: InputDecoration(
              labelText: 'Motivo de la cancelación *',
              errorText: _errorText,
              errorMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('confirm_cancel_donation_button'),
          onPressed: _isSubmitting ? null : _confirm,
          child: Text(_isSubmitting ? 'Cancelando...' : 'Confirmar cancelación'),
        ),
      ],
    );
  }
}
