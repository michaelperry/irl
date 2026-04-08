package com.irl.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val OceanBlue = Color(0xFF0066FF)
val EarthGreen = Color(0xFF00CC66)
val PureWhite = Color(0xFFFFFFFF)
val DeepSpace = Color(0xFF0A0A0A)
val SoftGray = Color(0xFFF5F5F7)
val MediumGray = Color(0xFF8E8E93)

private val DarkColorScheme = darkColorScheme(
    primary = OceanBlue,
    secondary = EarthGreen,
    tertiary = EarthGreen,
    background = DeepSpace,
    surface = Color(0xFF1C1C1E),
    onPrimary = PureWhite,
    onSecondary = PureWhite,
    onBackground = PureWhite,
    onSurface = PureWhite,
    surfaceVariant = Color(0xFF2C2C2E),
    onSurfaceVariant = MediumGray
)

private val LightColorScheme = lightColorScheme(
    primary = OceanBlue,
    secondary = EarthGreen,
    tertiary = EarthGreen,
    background = SoftGray,
    surface = PureWhite,
    onPrimary = PureWhite,
    onSecondary = PureWhite,
    onBackground = DeepSpace,
    onSurface = DeepSpace,
    surfaceVariant = Color(0xFFE5E5EA),
    onSurfaceVariant = MediumGray
)

val IRLTypography = Typography(
    displayLarge = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 48.sp,
        lineHeight = 56.sp,
        letterSpacing = (-1).sp
    ),
    headlineLarge = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 32.sp,
        lineHeight = 40.sp,
        letterSpacing = (-0.5).sp
    ),
    headlineMedium = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp,
        lineHeight = 32.sp
    ),
    titleLarge = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 20.sp,
        lineHeight = 28.sp
    ),
    titleMedium = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp
    ),
    bodyLarge = TextStyle(
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    bodyMedium = TextStyle(
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp
    ),
    labelLarge = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    labelMedium = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
)

@Composable
fun IRLTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = IRLTypography,
        content = content
    )
}
