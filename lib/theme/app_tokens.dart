import 'package:flutter/material.dart';

/// 디자인 토큰 (임시값). 본격 UI 작업 때 ui-ux-pro-max/hallmark 기준으로 교체.
abstract final class AppColors {
  static const cream = Color(0xFFFFF6E9);
  static const ink = Color(0xFF2E2A26);
  static const tabby = Color(0xFFE8943A);
  static const muted = Color(0xFF8A8178);

  // 냥냥 합체
  static const box = Color(0xFFC8955C);
  static const boxInner = Color(0xFFEBD3AE);
  static const boxShadow = Color(0xFFA9763F);
  static const danger = Color(0xFFD9534F);
  static const churu = Color(0xFFE86A6A);
  static const cucumber = Color(0xFF5FA052);
  static const cucumberDark = Color(0xFF3E7B37);
  static const star = Color(0xFFF2B233);

  // 냥냥 새총
  static const sky = Color(0xFFDDEFF5);
  static const hill = Color(0xFFBFDDB0);
  static const grass = Color(0xFF8CC063);
  static const soil = Color(0xFF9C7550);
  static const cardboard = Color(0xFFD9A96A);
  static const cardboardDark = Color(0xFFA9773D);
  static const wood = Color(0xFFB9804A);
  static const woodDark = Color(0xFF7D5230);
  static const brick = Color(0xFFC0604A);
  static const brickDark = Color(0xFF86392A);
  static const mouse = Color(0xFFA3A7AE);
  static const mouseEar = Color(0xFFF2A7B5);
  static const slingWood = Color(0xFF8A5A2E);
  static const rubber = Color(0xFF5B3A26);
  static const bird = Color(0xFF4C86C6);
  static const birdBelly = Color(0xFFF4F1E8);
  static const beak = Color(0xFFF2A33A);
  static const sun = Color(0xFFFFC93C);
  static const sunset = Color(0xFFFF8A4C);
  static const moon = Color(0xFFF4F1D0);
  static const moonShade = Color(0xFFD9D3A8);
  /// 알파벳 A~F 방울 색.
  static const letters = [
    Color(0xFFE85D75), // A
    Color(0xFFF08A3C), // B
    Color(0xFFE0B21F), // C
    Color(0xFF4FAE5B), // D
    Color(0xFF3B8FE0), // E
    Color(0xFF8A62D6), // F
  ];
  static const bungeoppang = Color(0xFFD99A4E);
  static const bungeoppangDark = Color(0xFF9A5E24);
  static const bungeoppangLight = Color(0xFFF2C27F);

  /// 고양이 털 색. 블록/캐릭터 공용.
  static const furs = [
    Color(0xFFE8943A), // 치즈
    Color(0xFF8D8F99), // 회색
    Color(0xFF3B3633), // 까망
    Color(0xFFF2D3A2), // 크림
    Color(0xFFA0673F), // 갈색
    Color(0xFF6E5A4E), // 샴 포인트
  ];
}

/// 냥냥 새총 풍경 색. 스테이지마다 낮 → 노을 → 밤이 돌아간다.
class SlingScenePalette {
  const SlingScenePalette({
    required this.skyTop,
    required this.skyBottom,
    required this.hillFar,
    required this.hillNear,
    required this.river,
    required this.riverLight,
    required this.leaf,
    required this.leafDark,
    required this.trunk,
    required this.grass,
    required this.soil,
    required this.cloud,
    required this.hud,
    required this.hudMuted,
  });

  final Color skyTop, skyBottom, hillFar, hillNear, river, riverLight;
  final Color leaf, leafDark, trunk, grass, soil, cloud;

  /// 하늘 위에 띄우는 메뉴 글자색.
  final Color hud, hudMuted;
}

abstract final class SlingScenes {
  static const day = SlingScenePalette(
    skyTop: Color(0xFF8FCBEB),
    skyBottom: Color(0xFFDDF1F7),
    hillFar: Color(0xFFB9D9C4),
    hillNear: Color(0xFFA6D08F),
    river: Color(0xFF6DB7D8),
    riverLight: Color(0xFFD5F0FA),
    leaf: Color(0xFF6FAE5A),
    leafDark: Color(0xFF4F8A45),
    trunk: Color(0xFF8A5A2E),
    grass: Color(0xFF8CC063),
    soil: Color(0xFF9C7550),
    cloud: Color(0xFFFFFFFF),
    hud: AppColors.ink,
    hudMuted: AppColors.muted,
  );
  static const sunset = SlingScenePalette(
    skyTop: Color(0xFFE9795F),
    skyBottom: Color(0xFFFFD39A),
    hillFar: Color(0xFFCFA38C),
    hillNear: Color(0xFFB7A06A),
    river: Color(0xFFE39A7C),
    riverLight: Color(0xFFFFE0C4),
    leaf: Color(0xFF80994E),
    leafDark: Color(0xFF5E7440),
    trunk: Color(0xFF6E4526),
    grass: Color(0xFF93A857),
    soil: Color(0xFF86603F),
    cloud: Color(0xFFFFE6D6),
    hud: AppColors.ink,
    hudMuted: Color(0xFF6B4E3D),
  );
  static const night = SlingScenePalette(
    skyTop: Color(0xFF0E1736),
    skyBottom: Color(0xFF34457A),
    hillFar: Color(0xFF2B3D5C),
    hillNear: Color(0xFF2E4D47),
    river: Color(0xFF28497A),
    riverLight: Color(0xFF8FB4E6),
    leaf: Color(0xFF2F5A48),
    leafDark: Color(0xFF223F35),
    trunk: Color(0xFF3E2C22),
    grass: Color(0xFF41704A),
    soil: Color(0xFF4A3A2E),
    cloud: Color(0xFF5A6993),
    hud: Color(0xFFFFFFFF),
    hudMuted: Color(0xFFB9C3DE),
  );
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
}

ThemeData buildAppTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tabby,
        surface: AppColors.cream,
      ),
      scaffoldBackgroundColor: AppColors.cream,
    );
