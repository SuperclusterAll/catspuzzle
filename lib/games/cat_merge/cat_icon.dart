import 'package:flutter/widgets.dart';

import '../../core/items.dart';
import 'cat_art.dart';
import 'cat_tiers.dart';
import 'merge_items.dart';

/// 고양이 한 마리 아이콘 (HUD, 도감, 합체 순서표).
class CatIcon extends StatelessWidget {
  const CatIcon({
    super.key,
    required this.tier,
    this.coat = CatCoat.base,
    required this.size,
    this.silhouette = false,
  });

  final int tier;
  final CatCoat coat;
  final double size;
  final bool silhouette;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CatPainter(tier, coat, silhouette)),
      );
}

class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, required this.item, required this.size});
  final ItemId item;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ItemPainter(item)),
      );
}

/// "다음" 미리보기처럼 고양이/아이템이 섞여 나오는 자리.
class DropIcon extends StatelessWidget {
  const DropIcon({super.key, required this.spec, required this.size});
  final DropSpec spec;
  final double size;

  @override
  Widget build(BuildContext context) {
    final item = spec.item;
    return item != null
        ? ItemIcon(item: item, size: size)
        : CatIcon(tier: spec.tier, coat: spec.coat, size: size);
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter(this.tier, this.coat, this.silhouette);
  final int tier;
  final CatCoat coat;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    // 귀(사자는 갈기)가 튀어나오므로 여유를 두고 살짝 아래로 내려 그린다.
    final r = size.width / (tier == lionTier ? 2.7 : 2.3);
    canvas.translate(size.width / 2, size.height / 2 + r * 0.12);
    paintCat(canvas, tier, coat, r, silhouette: silhouette);
  }

  @override
  bool shouldRepaint(_CatPainter old) =>
      old.tier != tier || old.coat != coat || old.silhouette != silhouette;
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.item);
  final ItemId item;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    paintItem(canvas, item, size.width / 2.8);
  }

  @override
  bool shouldRepaint(_ItemPainter old) => old.item != item;
}
