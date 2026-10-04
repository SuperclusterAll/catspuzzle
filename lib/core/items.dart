/// 인벤토리 아이템. 가격은 붕어빵 기준.
enum ItemId {
  churu('churu', '츄르', '떨어진 곳으로 주변 고양이를 끌어당겨요', 30),
  cucumber('cucumber', '오이', '닿은 고양이들이 깜짝 놀라 튀어 올라요', 30);

  const ItemId(this.key, this.label, this.description, this.price);
  final String key;
  final String label;
  final String description;
  final int price;

  static ItemId? fromKey(String key) =>
      values.where((i) => i.key == key).firstOrNull;
}
