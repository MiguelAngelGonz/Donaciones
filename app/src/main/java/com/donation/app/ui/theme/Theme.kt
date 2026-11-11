package com.donation.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DonationColors = lightColorScheme(
    primary = Primario,
    onPrimary = Color.White,
    secondary = Acento,
    onSecondary = TextoPrincipal,
    secondaryContainer = SuperficieSuave,
    onSecondaryContainer = TextoPrincipal,
    background = Fondo,
    onBackground = TextoPrincipal,
    surface = Superficie,
    onSurface = TextoPrincipal,
    surfaceVariant = SuperficieSuave,
    onSurfaceVariant = TextoPrincipal,
    surfaceContainerLowest = Superficie,
    surfaceContainerLow = Superficie,
    surfaceContainer = Superficie,
    surfaceContainerHigh = Superficie,
    surfaceContainerHighest = Superficie,
    error = ErrorRojo,
    onError = Color.White,
    outline = Contorno,
    outlineVariant = Contorno
)

@Composable
fun DonationTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DonationColors, content = content)
}
