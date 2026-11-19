import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top demo bar to switch active tenant user, simulate network errors (RNF-12),
/// and advance or reset the simulated clock for time-dependent flows.
class DemoTenantToolbar extends ConsumerWidget {
  const DemoTenantToolbar({super.key});

  String _formatDateTime(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)} '
        '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final accessibility = ref.watch(accessibilityProvider);
    final theme = Theme.of(context);
    final users = store.users;
    final activeUserId = store.activeUser?.id;

    return Material(
      color: accessibility.highContrast
          ? Colors.white
          : DonaPlusColors.primary.withValues(alpha: 0.08),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: accessibility.highContrast
                  ? Colors.black
                  : DonaPlusColors.borderLight,
              width: accessibility.highContrast ? 1.5 : 1.0,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        key: const Key('demo_user_selector'),
                        isDense: true,
                        value: activeUserId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        items: [
                          for (final user in users)
                            DropdownMenuItem<String?>(
                              value: user.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('@${user.nombreUsuario}'),
                                  if (user.esAdministrador) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.admin_panel_settings_outlined,
                                      size: 14,
                                    ),
                                  ] else if (user.esIntermediario) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin sesión'),
                          ),
                        ],
                        onChanged: store.setActiveUser,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => store.setSimulateNetworkError(
                    !store.simulateNetworkError,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Simular fallo de red',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: store.simulateNetworkError
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 28,
                        child: Switch(
                          key: const Key('simulate_network_error_switch'),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          value: store.simulateNetworkError,
                          onChanged: store.setSimulateNetworkError,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(store.currentTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                _ClockActionButton(
                  label: '+15m',
                  onPressed: () =>
                      store.advanceClock(const Duration(minutes: 15)),
                ),
                _ClockActionButton(
                  label: '+7d',
                  onPressed: () => store.advanceClock(const Duration(days: 7)),
                ),
                _ClockActionButton(
                  label: '+15d',
                  onPressed: () => store.advanceClock(const Duration(days: 15)),
                ),
                _ClockActionButton(
                  label: 'Reiniciar',
                  onPressed: store.resetToSeed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ClockActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
