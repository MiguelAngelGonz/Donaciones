import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter/material.dart';

/// Human-readable label for a [EstadoDonacion] value.
String labelForEstadoDonacion(EstadoDonacion estado) {
  return switch (estado) {
    EstadoDonacion.aceptada => 'Aceptada',
    EstadoDonacion.enEntrega => 'En entrega',
    EstadoDonacion.entregada => 'Entregada',
    EstadoDonacion.finalizada => 'Finalizada',
    EstadoDonacion.cancelada => 'Cancelada',
  };
}

/// Human-readable label for a [EstadoPropuesta] value.
String labelForEstadoPropuesta(EstadoPropuesta estado) {
  return switch (estado) {
    EstadoPropuesta.pendiente => 'Pendiente',
    EstadoPropuesta.aceptada => 'Aceptada',
    EstadoPropuesta.rechazada => 'Rechazada',
    EstadoPropuesta.retirada => 'Retirada',
  };
}

/// Formats a [DateTime] as `DD/MM/YYYY HH:MM`.
String formatDonationDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Formats a [DateTime] date only as `DD/MM/YYYY`.
String formatDonationDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}

/// Executes [store.acceptProposal] and maps domain exceptions to [onError].
Future<DonacionMock?> runAcceptProposal({
  required MockTenantStore store,
  required String proposalId,
  required String clientKey,
  required ValueChanged<String> onError,
}) async {
  try {
    return await store.acceptProposal(
      proposalId: proposalId,
      clientKey: clientKey,
    );
  } on NetworkException catch (e) {
    onError(e.message);
    return null;
  } on ValidationException catch (e) {
    onError(e.message);
    return null;
  } on UnauthorizedActionException catch (e) {
    onError(e.message);
    return null;
  }
}

/// Executes [store.rejectProposal] and maps domain exceptions to [onError].
Future<bool> runRejectProposal({
  required MockTenantStore store,
  required String proposalId,
  String? reason,
  required ValueChanged<String> onError,
}) async {
  try {
    await store.rejectProposal(proposalId: proposalId, reason: reason);
    return true;
  } on NetworkException catch (e) {
    onError(e.message);
    return false;
  } on ValidationException catch (e) {
    onError(e.message);
    return false;
  } on UnauthorizedActionException catch (e) {
    onError(e.message);
    return false;
  }
}

/// Status pill badge for a [DonacionMock] lifecycle state.
class DonationStatusBadge extends StatelessWidget {
  final EstadoDonacion estado;

  const DonationStatusBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final (Color bg, Color border, Color fg, IconData icon) = switch (estado) {
      EstadoDonacion.aceptada => (
        highContrast
            ? Colors.white
            : DonaPlusColors.primary.withValues(alpha: 0.1),
        highContrast ? Colors.black : DonaPlusColors.primary,
        highContrast ? Colors.black : DonaPlusColors.primary,
        Icons.handshake_outlined,
      ),
      EstadoDonacion.enEntrega => (
        highContrast
            ? DonaPlusColors.accentYellow
            : const Color(0xFFFFF4DC),
        highContrast ? Colors.black : const Color(0xFFB26A00),
        highContrast ? Colors.black : const Color(0xFF8C5200),
        Icons.local_shipping_outlined,
      ),
      EstadoDonacion.entregada => (
        highContrast
            ? Colors.white
            : DonaPlusColors.secondary.withValues(alpha: 0.15),
        highContrast ? Colors.black : DonaPlusColors.secondary,
        highContrast ? Colors.black : DonaPlusColors.primary,
        Icons.inventory_2_outlined,
      ),
      EstadoDonacion.finalizada => (
        highContrast
            ? DonaPlusColors.accentMint
            : DonaPlusColors.accentMint.withValues(alpha: 0.55),
        highContrast ? Colors.black : DonaPlusColors.primary,
        highContrast ? Colors.black : DonaPlusColors.primary,
        Icons.verified_outlined,
      ),
      EstadoDonacion.cancelada => (
        theme.colorScheme.errorContainer,
        highContrast ? Colors.black : theme.colorScheme.error,
        highContrast ? Colors.black : theme.colorScheme.onErrorContainer,
        Icons.cancel_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: highContrast ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            labelForEstadoDonacion(estado),
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill badge for a [PropuestaMock] state.
class ProposalStatusBadge extends StatelessWidget {
  final EstadoPropuesta estado;

  const ProposalStatusBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final (Color bg, Color border, Color fg) = switch (estado) {
      EstadoPropuesta.pendiente => (
        highContrast ? DonaPlusColors.accentYellow : const Color(0xFFFFF4DC),
        highContrast ? Colors.black : const Color(0xFFB26A00),
        highContrast ? Colors.black : const Color(0xFF8C5200),
      ),
      EstadoPropuesta.aceptada => (
        highContrast
            ? DonaPlusColors.accentMint
            : DonaPlusColors.accentMint.withValues(alpha: 0.55),
        highContrast ? Colors.black : DonaPlusColors.primary,
        highContrast ? Colors.black : DonaPlusColors.primary,
      ),
      EstadoPropuesta.rechazada => (
        theme.colorScheme.errorContainer,
        highContrast ? Colors.black : theme.colorScheme.error,
        highContrast ? Colors.black : theme.colorScheme.onErrorContainer,
      ),
      EstadoPropuesta.retirada => (
        theme.colorScheme.surfaceContainerHighest,
        highContrast ? Colors.black : theme.colorScheme.outline,
        theme.colorScheme.onSurface,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: highContrast ? 1.5 : 1.0),
      ),
      child: Text(
        labelForEstadoPropuesta(estado),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Responsive visual step timeline for donation progress (CU-30).
class DonationProgressTimeline extends StatelessWidget {
  final EstadoDonacion estado;

  const DonationProgressTimeline({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    if (estado == EstadoDonacion.cancelada) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _StepPill(
            label: 'Solicitud',
            completed: true,
            active: false,
            highContrast: highContrast,
          ),
          _StepPill(
            label: 'Cancelada',
            completed: false,
            active: true,
            isError: true,
            highContrast: highContrast,
          ),
        ],
      );
    }

    final currentStep = switch (estado) {
      EstadoDonacion.aceptada => 1,
      EstadoDonacion.enEntrega => 2,
      EstadoDonacion.entregada => 3,
      EstadoDonacion.finalizada => 4,
      EstadoDonacion.cancelada => 0,
    };

    const labels = [
      'Solicitud',
      'Aceptada',
      'En entrega',
      'Entregada',
      'Confirmación',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          _StepPill(
            label: labels[i],
            completed: i < currentStep || estado == EstadoDonacion.finalizada,
            active: i == currentStep && estado != EstadoDonacion.finalizada,
            highContrast: highContrast,
          ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool completed;
  final bool active;
  final bool isError;
  final bool highContrast;

  const _StepPill({
    required this.label,
    required this.completed,
    required this.active,
    this.isError = false,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;

    if (isError) {
      bg = theme.colorScheme.errorContainer;
      border = highContrast ? Colors.black : theme.colorScheme.error;
      fg = highContrast ? Colors.black : theme.colorScheme.onErrorContainer;
      icon = Icons.cancel_outlined;
    } else if (completed) {
      bg = highContrast
          ? DonaPlusColors.accentMint
          : DonaPlusColors.accentMint.withValues(alpha: 0.55);
      border = highContrast ? Colors.black : DonaPlusColors.secondary;
      fg = highContrast ? Colors.black : DonaPlusColors.primary;
      icon = Icons.check_circle;
    } else if (active) {
      bg = highContrast
          ? DonaPlusColors.accentYellow
          : DonaPlusColors.secondary.withValues(alpha: 0.16);
      border = highContrast ? Colors.black : DonaPlusColors.secondary;
      fg = highContrast ? Colors.black : DonaPlusColors.primary;
      icon = Icons.radio_button_checked;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      border = theme.colorScheme.outline;
      fg = theme.colorScheme.onSurface.withValues(alpha: 0.72);
      icon = Icons.radio_button_unchecked;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: (completed || active)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
