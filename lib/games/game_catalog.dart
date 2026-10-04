import 'package:flutter/widgets.dart';

import '../core/models/cat.dart';
import '../core/save_store.dart';
import 'cat_merge/cat_merge_game.dart';
import 'cat_merge/cat_merge_screen.dart';
import 'cat_sling/cat_sling_game.dart';
import 'cat_sling/cat_sling_screen.dart';

typedef GameLauncher = Widget Function(SaveStore store, Cat cat);

class GameEntry {
  const GameEntry(
      {required this.id, required this.title, required this.blurb, this.launch});
  final String id;
  final String title;
  final String blurb;

  /// null이면 아직 준비 중.
  final GameLauncher? launch;
}

final gameCatalog = <GameEntry>[
  GameEntry(
    id: CatMergeGame.id,
    title: '냥냥 합체',
    blurb: '같은 고양이끼리 부딪혀 더 큰 고양이로',
    launch: (store, cat) => CatMergeScreen(store: store, cat: cat),
  ),
  GameEntry(
    id: CatSlingGame.id,
    title: '냥냥 새총',
    blurb: '고양이를 날려 상자 탑의 쥐를 잡아요',
    launch: (store, cat) => CatSlingScreen(store: store, cat: cat),
  ),
  const GameEntry(id: 'cat_sort', title: '캣타워 정리', blurb: '같은 무늬끼리 모아요'),
  const GameEntry(id: 'yarn', title: '털실 풀기', blurb: '엉킨 털실을 풀어 구출해요'),
];
