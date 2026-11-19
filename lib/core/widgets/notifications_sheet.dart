import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the notifications inbox bottom sheet for the active user.
Future<void> showNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const NotificationsSheet(),
  );
}

/// Header bell icon button displaying the unread notification badge count.
class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final unreadCount = activeUser == null
        ? 0
        : store
              .getNotificationsForUser(activeUser.id)
              .where((n) => !n.leida)
              .length;

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => showNotificationsSheet(context),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

/// Bottom sheet displaying internal notifications and read toggles.
class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  String _formatDate(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)} '
        '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  IconData _iconForType(TipoNotificacion tipo) {
    return switch (tipo) {
      TipoNotificacion.nuevaCoincidencia => Icons.auto_awesome,
      TipoNotificacion.nuevaPropuesta => Icons.mark_chat_unread_outlined,
      TipoNotificacion.propuestaAceptada => Icons.check_circle_outline,
      TipoNotificacion.propuestaRechazada => Icons.cancel_outlined,
      TipoNotificacion.cambioEstadoDonacion => Icons.local_shipping_outlined,
      TipoNotificacion.decisionRolIntermediario => Icons.verified_user_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);

    final notifications = activeUser == null
        ? const <NotificacionMock>[]
        : store.getNotificationsForUser(activeUser.id);
    final unread = notifications.where((n) => !n.leida).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notificaciones',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (unread.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        for (final item in unread) {
                          store.markNotificationAsRead(item.id);
                        }
                      },
                      child: const Text('Marcar todas'),
                    ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activeUser == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Inicia sesión para consultar tus avisos.'),
                  ),
                )
              else if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No tienes notificaciones por ahora.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isUnread = !notification.leida;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isUnread
                              ? DonaPlusColors.accentMint.withValues(alpha: 0.7)
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.primary,
                          child: Icon(_iconForType(notification.tipo)),
                        ),
                        title: Text(
                          notification.mensaje,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(_formatDate(notification.fecha)),
                        trailing: isUnread
                            ? IconButton(
                                tooltip: 'Marcar como leída',
                                icon: Icon(
                                  Icons.mark_email_read_outlined,
                                  color: theme.colorScheme.secondary,
                                ),
                                onPressed: () => store.markNotificationAsRead(
                                  notification.id,
                                ),
                              )
                            : const Icon(
                                Icons.done_all,
                                size: 18,
                                color: Colors.grey,
                              ),
                        onTap: isUnread
                            ? () =>
                                  store.markNotificationAsRead(notification.id)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
