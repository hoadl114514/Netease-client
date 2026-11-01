import 'package:flutter/material.dart';

/// 颜色。整体沿用"内容优先的暗色"思路：界面本身保持无彩，颜色交给封面；
/// 唯一的品牌色是樱花粉 [accent]，只用在播放、选中、进度这类功能性位置。
abstract final class AppColors {
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF181818);
  static const surfaceHigh = Color(0xFF1F1F1F);
  static const card = Color(0xFF202020);
  static const cardHover = Color(0xFF2A2A2A);
  static const border = Color(0xFF2E2E2E);
  static const borderStrong = Color(0xFF4D4D4D);
  static const outline = Color(0xFF7C7C7C);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textMuted = Color(0xFF7A7A7A);

  /// 樱花粉。
  static const accent = Color(0xFFF5A3C7);

  /// 更浅的樱花粉，用于沉浸式播放页里的大号文字与歌词高亮。
  static const accentSoft = Color(0xFFFFD3E6);
  static const onAccent = Color(0xFF1A0F14);

  static const negative = Color(0xFFF3727F);
}

abstract final class AppRadius {
  static const double tag = 4;
  static const double card = 8;
  static const double panel = 12;
  static const double cover = 16;
  static const double pill = 999;
}

abstract final class AppShadows {
  static const medium = [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 8), blurRadius: 8)];
  static const heavy = [BoxShadow(color: Color(0x80000000), offset: Offset(0, 8), blurRadius: 24)];
}

abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentSoft,
      onSecondary: AppColors.onAccent,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surfaceHigh,
      surfaceContainerHigh: AppColors.card,
      surfaceContainerHighest: AppColors.cardHover,
      outline: AppColors.outline,
      outlineVariant: AppColors.border,
      error: AppColors.negative,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    // 紧凑的字号体系：10–24 之间，靠字重而非字号拉开层级。
    final text = base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2),
          titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
          titleSmall: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          labelSmall: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

    return base.copyWith(
      textTheme: text,
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardHover,
          borderRadius: BorderRadius.circular(AppRadius.tag),
          boxShadow: AppShadows.heavy,
        ),
        textStyle: text.bodySmall,
        waitDuration: const Duration(milliseconds: 500),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: AppColors.accentSoft,
        overlayColor: Color(0x22F5A3C7),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        trackShape: RoundedRectSliderTrackShape(),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(AppRadius.pill),
        thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
