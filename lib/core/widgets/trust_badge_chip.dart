import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter/material.dart';

/// Displays a user's Trust Profile badge or progress toward earning it (CU-04).
class TrustBadgeChip extends StatelessWidget {
  final UsuarioMock usuario;
  final bool compact;

  const TrustBadgeChip({
    super.key,
    required this.usuario,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = _isHighContrast(context);
    final ratingLabel = usuario.promedioCalificacion.toStringAsFixed(1);

    if (usuario.perfilConfianzaOtorgado) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: highContrast
              ? DonaPlusColors.accentYellow
              : DonaPlusColors.accentMint.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highContrast ? Colors.black : DonaPlusColors.primary,
            width: highContrast ? 1.5 : 1.0,
          ),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.verified,
              size: compact ? 15 : 17,
              color: highContrast ? Colors.black : DonaPlusColors.primary,
            ),
            Text(
              'Perfil de Confianza',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: highContrast ? Colors.black : DonaPlusColors.primary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: compact ? 15 : 16,
                  color: highContrast ? Colors.black : const Color(0xFFB26A00),
                ),
                const SizedBox(width: 2),
                Text(
                  ratingLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highContrast ? Colors.black : DonaPlusColors.primary,
                  ),
                ),
              ],
            ),
            Text(
              compact
                  ? '${usuario.donacionesFinalizadas} don.'
                  : '${usuario.donacionesFinalizadas} donaciones',
              style: theme.textTheme.labelSmall?.copyWith(
                color: highContrast ? Colors.black : DonaPlusColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final clampedDonations = usuario.donacionesFinalizadas.clamp(0, 5);
    final String progressLabel;
    if (compact) {
      progressLabel = 'En progreso · ★ $ratingLabel';
    } else if (usuario.donacionesFinalizadas >= 5 && usuario.numeroResenas < 3) {
      progressLabel =
          'En progreso ($clampedDonations/5 donaciones · ${usuario.numeroResenas}/3 reseñas · ★ $ratingLabel)';
    } else if (usuario.donacionesFinalizadas >= 5) {
      progressLabel =
          'En progreso ($clampedDonations/5 donaciones · ★ $ratingLabel / 4.0)';
    } else {
      progressLabel =
          'En progreso ($clampedDonations/5 donaciones · ★ $ratingLabel)';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highContrast ? Colors.black : DonaPlusColors.borderLight,
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: compact ? 14 : 16,
            color: theme.colorScheme.onSurface,
          ),
          Text(
            progressLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  bool _isHighContrast(BuildContext context) {
    return Theme.of(context).colorScheme.outline == Colors.black;
  }
}
