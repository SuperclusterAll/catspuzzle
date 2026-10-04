import 'dart:io';

import 'package:catspuzzle/games/cat_merge/cat_art.dart';
import 'package:catspuzzle/games/cat_merge/cat_tiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/gen_cat_svgs.dart' as gen;

void main() {
  test('생성기의 털색·무늬·표정 목록이 게임 정의와 같음', () {
    expect(gen.furHex.length, catTiers.length);
    for (var t = 0; t < catTiers.length; t++) {
      final argb = catTiers[t].fur.toARGB32() & 0xFFFFFF;
      expect(
        gen.furHex[t],
        argb.toRadixString(16).padLeft(6, '0'),
        reason: catTiers[t].name,
      );
      expect(gen.isDark(t), darkFur(t), reason: catTiers[t].name);
    }
    expect(gen.coats, CatCoat.values.map((c) => c.name));
    expect(gen.faces, CatFace.values.map((f) => f.name));
    expect(gen.lionTier, lionTier);
  });

  test('모든 조합의 SVG 파일이 있음 (생성기를 돌렸는지)', () {
    for (var t = 0; t < catTiers.length; t++) {
      for (final p in CatCoat.values) {
        expect(
          File(CatArt.bodyPath(t, p)).existsSync(),
          isTrue,
          reason: CatArt.bodyPath(t, p),
        );
      }
    }
    for (var t = 0; t < catTiers.length; t++) {
      for (final f in CatFace.values) {
        expect(
          File(CatArt.facePath(t, f)).existsSync(),
          isTrue,
          reason: CatArt.facePath(t, f),
        );
      }
    }
  });
}
