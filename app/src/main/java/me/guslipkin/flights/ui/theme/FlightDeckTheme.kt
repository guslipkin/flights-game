package me.guslipkin.flights.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

object FlightDeckColors {
    // Flight-Deck Dark Surfaces
    val Background = Color(0xFF0D1117)
    val RadarBackground = Color(0xFF090D12)
    val RadarGrid = Color(0xFF121C29)
    val CoastlineVector = Color(0xFF475B73)
    val SurfaceCard = Color(0xFF131A24)
    val SurfaceElevated = Color(0xFF1A2331)
    val SelectedRowBg = Color(0xFF28261E)
    val SelectedRowBorder = Color(0xFFE69F00)
    val BorderSubtle = Color(0xFF233246)
    val BorderAccent = Color(0xFF334C6B)

    // Typography Colors
    val TextPrimary = Color(0xFFF0F6FC)
    val TextSecondary = Color(0xFF9BAEC4)
    val TextMuted = Color(0xFF63768D)

    // Okabe-Ito Colorblind-Safe Palette (from jotto-cli)
    val AccentSkyBlue = Color(0xFF56B4E9)     // Flown route & UI accent
    val PositiveGreen = Color(0xFF009E73)     // Current airport & shortest route
    val WarningOrange = Color(0xFFE69F00)     // Available options, changed letter, preview hop
    val DestinationPurple = Color(0xFFCC79A7) // Destination airport (★)
    val NegativeVermilion = Color(0xFFD55E00) // Alert / error
}

private val FlightDeckColorScheme = darkColorScheme(
    primary = FlightDeckColors.AccentSkyBlue,
    onPrimary = Color.Black,
    secondary = FlightDeckColors.PositiveGreen,
    onSecondary = Color.Black,
    tertiary = FlightDeckColors.DestinationPurple,
    background = FlightDeckColors.Background,
    onBackground = FlightDeckColors.TextPrimary,
    surface = FlightDeckColors.SurfaceCard,
    onSurface = FlightDeckColors.TextPrimary,
    surfaceVariant = FlightDeckColors.SurfaceElevated,
    onSurfaceVariant = FlightDeckColors.TextSecondary,
    error = FlightDeckColors.NegativeVermilion
)

val FlightDeckTypography = Typography(
    titleLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp,
        letterSpacing = 1.1.sp,
        color = FlightDeckColors.TextPrimary
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        letterSpacing = 0.5.sp,
        color = FlightDeckColors.TextPrimary
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        color = FlightDeckColors.TextPrimary
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        color = FlightDeckColors.TextSecondary
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 13.sp,
        color = FlightDeckColors.TextPrimary
    )
)

@Composable
fun FlightDeckTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = FlightDeckColorScheme,
        typography = FlightDeckTypography,
        content = content
    )
}
