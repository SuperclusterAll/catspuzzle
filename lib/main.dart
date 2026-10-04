import 'package:flutter/material.dart';

import 'core/save_store.dart';
import 'games/cat_merge/cat_art.dart';
import 'meta/home_screen.dart';
import 'theme/app_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (store, _) = await (SaveStore.open(), CatArt.load()).wait;
  runApp(CatsPuzzleApp(store: store));
}

class CatsPuzzleApp extends StatelessWidget {
  const CatsPuzzleApp({super.key, required this.store});
  final SaveStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'catspuzzle',
        theme: buildAppTheme(),
        home: HomeScreen(store: store),
      );
}
