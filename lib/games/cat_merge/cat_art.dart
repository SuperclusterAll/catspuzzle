import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_tokens.dart';
import 'cat_tiers.dart';

/// 표정. 단계마다 기본 표정이 있고, 합체/오이/츄르 같은 사건에 잠깐 바뀐다.
/// 이름은 assets/cats/face_{name}_*.svg 와 같다.
enum CatFace {
  calm,
  sleepy,
  sparkle,
  smile,
  happy,
  wink,
  content,
  bleh,
  proud,
  surprised,
  love,
  blink;

  bool get opensEyes => switch (this) {
        calm || sparkle || smile || wink || proud => true,
        _ => false,
      };
}

/// 품종별 기본 표정 (앙고라는 오드아이가 보이게 뜨고, 페르시안은 졸고, 사자는 거만하게).
const tierFaces = [
  CatFace.calm,
  CatFace.sparkle,
  CatFace.calm,
  CatFace.smile,
  CatFace.calm,
  CatFace.sparkle,
  CatFace.happy,
  CatFace.wink,
  CatFace.sleepy,
  CatFace.bleh,
  CatFace.proud,
];

/// 어두운 털 품종 (얼굴 선을 밝게 그린다).
bool darkFur(int tier) => catTiers[tier].fur.computeLuminance() < 0.12;

/// assets/cats/ 의 SVG 일러스트 (tool/gen_cat_svgs.dart 로 생성).
/// 머리(품종×털색)와 얼굴(품종×표정) 두 층을 겹쳐 그린다.
abstract final class CatArt {
  static const dir = 'assets/cats';

  /// SVG 한 장의 크기 (반지름 1 고양이 기준 -1.6..1.6).
  static const extent = 1.6;

  static final _bodies = <(int, CatCoat), Picture>{};
  static final _faces = <(int, CatFace), Picture>{};

  static bool get isLoaded => _bodies.isNotEmpty;

  static String bodyPath(int tier, CatCoat p) =>
      '$dir/body_t${tier}_${p.name}.svg';
  static String facePath(int tier, CatFace f) =>
      '$dir/face_t${tier}_${f.name}.svg';

  /// 앱 시작 시 한 번. 모든 조합을 Picture로 만들어 둔다.
  static Future<void> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<Picture> pic(String path) async =>
        (await vg.loadPicture(SvgStringLoader(await b.loadString(path)), null))
            .picture;

    await Future.wait([
      for (var t = 0; t < catTiers.length; t++)
        for (final p in CatCoat.values)
          pic(bodyPath(t, p)).then((v) => _bodies[(t, p)] = v),
      for (var t = 0; t < catTiers.length; t++)
        for (final f in CatFace.values)
          pic(facePath(t, f)).then((v) => _faces[(t, f)] = v),
    ]);
  }
}

final _layerPaint = Paint();
final _silhouette =
    ColorFilter.mode(AppColors.muted.withValues(alpha: 0.28), BlendMode.srcIn);

/// 원점 기준 반지름 [r]짜리 고양이. 게임 월드와 Flutter 위젯 양쪽에서 쓴다.
/// [silhouette]는 도감의 미발견 칸. [CatArt.load] 전에는 아무것도 그리지 않는다.
void paintCat(Canvas canvas, int tier, CatCoat coat, double r,
    {CatFace? face,
    bool blink = false,
    double opacity = 1,
    bool silhouette = false}) {
  final body = CatArt._bodies[(tier, silhouette ? CatCoat.base : coat)];
  if (body == null) return;
  var f = face ?? tierFaces[tier];
  if (blink && f.opensEyes) f = CatFace.blink;

  final layered = opacity < 1 || silhouette;
  canvas.save();
  if (layered) {
    _layerPaint
      ..color = Color.fromRGBO(0, 0, 0, opacity)
      ..colorFilter = silhouette ? _silhouette : null;
    canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: CatArt.extent * r),
        _layerPaint);
  }
  canvas.scale(r);
  canvas.translate(-CatArt.extent, -CatArt.extent);
  canvas.drawPicture(body);
  if (!silhouette) canvas.drawPicture(CatArt._faces[(tier, f)]!);
  if (layered) canvas.restore();
  canvas.restore();
}
