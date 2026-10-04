class Cat {
  const Cat({
    required this.id,
    required this.breedId,
    required this.name,
    required this.level,
    required this.exp,
    required this.affection,
    required this.hunger,
    required this.obtainedAt,
    this.lastFedAt,
  });

  final int id;
  final String breedId;
  final String name;
  final int level;
  final int exp;
  final int affection;
  final int hunger;
  final DateTime obtainedAt;
  final DateTime? lastFedAt;

  factory Cat.fromRow(Map<String, Object?> row) {
    final fed = row['last_fed_at'] as int?;
    return Cat(
      id: row['id'] as int,
      breedId: row['breed_id'] as String,
      name: row['name'] as String,
      level: row['level'] as int,
      exp: row['exp'] as int,
      affection: row['affection'] as int,
      hunger: row['hunger'] as int,
      obtainedAt: DateTime.fromMillisecondsSinceEpoch(row['obtained_at'] as int),
      lastFedAt: fed == null ? null : DateTime.fromMillisecondsSinceEpoch(fed),
    );
  }
}
