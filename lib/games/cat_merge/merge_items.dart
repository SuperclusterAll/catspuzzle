import 'dart:ui';

import '../../core/items.dart';
import '../../theme/app_tokens.dart';
import 'cat_tiers.dart';

extension MergeItemPhysics on ItemId {
  /// 물리 월드 반지름(m). 그림은 이보다 조금 삐져나온다.
  double get radius => switch (this) {
        ItemId.churu => 0.42,
        ItemId.cucumber => 0.45,
      };
}

/// 떨어뜨릴 것 하나: 고양이(단계+무늬) 또는 아이템.
class DropSpec {
  const DropSpec.cat(this.tier, this.coat) : item = null;
  const DropSpec.item(ItemId this.item)
      : tier = 0,
        coat = CatCoat.base;

  final int tier;
  final CatCoat coat;
  final ItemId? item;

  double get radius => item?.radius ?? catTiers[tier].radius;
}

final _paint = Paint();

void paintItem(Canvas canvas, ItemId item, double r, {double opacity = 1}) {
  Color a(Color c) => c.withValues(alpha: c.a * opacity);
  switch (item) {
    case ItemId.churu:
      canvas.save();
      canvas.rotate(-0.35);
      _paint.color = a(AppColors.churu);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 0.95 * r, height: 2.4 * r),
              Radius.circular(0.2 * r)),
          _paint);
      _paint.color = a(const Color(0xFFFFFFFF));
      canvas.drawRect(
          Rect.fromLTWH(-0.475 * r, -1.2 * r, 0.95 * r, 0.32 * r), _paint);
      _paint.color = a(AppColors.cream);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(0, 0.15 * r), width: 0.6 * r, height: 0.9 * r),
              Radius.circular(0.12 * r)),
          _paint);
      // 물고기 마크
      _paint.color = a(AppColors.churu);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, 0.1 * r), width: 0.34 * r, height: 0.2 * r),
          _paint);
      canvas.drawPath(
          Path()
            ..moveTo(0.14 * r, 0.1 * r)
            ..lineTo(0.28 * r, 0.0)
            ..lineTo(0.28 * r, 0.2 * r)
            ..close(),
          _paint);
      canvas.restore();
    case ItemId.cucumber:
      canvas.save();
      canvas.rotate(0.3);
      _paint.color = a(AppColors.cucumber);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 2.5 * r, height: 1.05 * r),
              Radius.circular(0.52 * r)),
          _paint);
      _paint.color = a(AppColors.cucumberDark);
      for (final (x, y) in [(-0.6, -0.15), (-0.1, 0.2), (0.4, -0.18), (0.8, 0.15)]) {
        canvas.drawCircle(Offset(x * r, y * r), 0.07 * r, _paint);
      }
      _paint.color = a(const Color(0xFFB9DB8A));
      canvas.drawCircle(Offset(-1.05 * r, 0), 0.22 * r, _paint);
      canvas.restore();
  }
}
