import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/cat.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/rewards.dart';
import '../../core/save_store.dart';
import '../../theme/app_tokens.dart';
import '../cat_merge/cat_icon.dart';
import '../cat_merge/merge_sfx.dart';
import 'cat_sling_game.dart';
import 'sling_levels.dart';

/// 냥냥 새총 (스테이지 모드).
///
/// 들어오면 아직 못 깬 첫 스테이지부터. 스테이지 제목을 누르면 깬 스테이지를 다시 고를 수 있다.
class CatSlingScreen extends StatefulWidget {
  const CatSlingScreen({super.key, required this.store, required this.cat});

  final SaveStore store;
  final Cat cat;

  @override
  State<CatSlingScreen> createState() => _CatSlingScreenState();
}

class _CatSlingScreenState extends State<CatSlingScreen> {
  late final CatSlingGame _game = CatSlingGame(
    onEnd: _onEnd,
    onLetter: _onLetter,
  );

  /// 모은 알파벳 (스테이지를 넘어 이어진다).
  Set<String> _letters = {};
  static const _lettersKey = 'sling_letters';

  /// A~F를 다 모으면 받는 붕어빵.
  static const letterBonusFish = 100;

  int _level = 1;
  Map<int, int> _stars = const {};
  bool _sound = true;
  bool _showRule = true;

  SaveStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    // 새총은 가로 화면에서. 나가면 앱 기본(세로)으로 돌려놓는다.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Sfx.load();
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _load() async {
    final stars = await _store.progress.allStars(CatSlingGame.id);
    final highest = await _store.progress.highestCleared(CatSlingGame.id);
    final sound = await _store.settings.getBool(
      SettingsRepository.soundOn,
      fallback: true,
    );
    final saved = await _store.settings.get(_lettersKey) ?? '';
    _letters = saved.split('').toSet();
    _game.letters = {..._letters};
    if (!mounted) return;
    Sfx.enabled = sound;
    setState(() {
      _stars = stars;
      _sound = sound;
    });
    _start(highest + 1);
  }

  Future<void> _onLetter(String l) async {
    final all = {..._letters, l};
    final complete = all.length == CatSlingGame.alphabet.length;
    setState(() => _letters = complete ? all : all);
    if (!complete) {
      await _store.settings.set(_lettersKey, all.join());
      return;
    }
    // 다 모았다: 보너스 주고 처음부터 다시 모은다.
    await _store.wallet.earn(
      Currency.bungeoppang,
      letterBonusFish,
      reason: 'sling_letters',
      source: CatSlingGame.id,
    );
    await _store.settings.set(_lettersKey, '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2200),
        content: Text(
          'ABCDEF 완성! 붕어빵 +$letterBonusFish · 점수 +${CatSlingGame.letterBonusScore}',
        ),
      ),
    );
    // 완성된 줄을 잠깐 보여준 뒤 비운다
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _letters = {});
    _game.letters = {};
  }

  void _start(int level) {
    setState(() {
      _level = level;
      _showRule = true;
    });
    _game.startLevel(SlingLevels.build(level));
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted && _level == level) setState(() => _showRule = false);
    });
  }

  Future<void> _toggleSound() async {
    final on = !_sound;
    Sfx.enabled = on;
    setState(() => _sound = on);
    await _store.settings.setBool(SettingsRepository.soundOn, on);
  }

  Future<void> _pickLevel() async {
    final top = (_stars.keys.fold(0, (a, b) => a > b ? a : b)) + 1;
    _game.pauseEngine();
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => _LevelSheet(top: top, stars: _stars, current: _level),
    );
    _game.resumeEngine();
    if (picked != null) _start(picked);
  }

  Future<void> _onEnd(SlingResult r) async {
    var reward = GameReward.none;
    if (r.cleared) {
      reward = await _store.finishStage(
        gameId: CatSlingGame.id,
        level: _level,
        stars: r.stars,
        score: r.score,
        catId: widget.cat.id,
      );
      final stars = await _store.progress.allStars(CatSlingGame.id);
      if (mounted) setState(() => _stars = stars);
    } else {
      await _store.progress.recordPlay(CatSlingGame.id, r.score);
    }
    // 마지막 연출을 조금 보여준다
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final next = await showDialog<_Next>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        level: _level,
        result: r,
        reward: reward,
        cat: widget.cat,
      ),
    );
    if (!mounted) return;
    switch (next) {
      case _Next.again:
        _start(_level);
      case _Next.next:
        _start(_level + 1);
      case _Next.quit || null:
        Navigator.of(context).pop();
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final best = _stars[_level] ?? 0;
    // 밤 스테이지에서는 어두운 하늘 위라 밝은 글자로
    final pal = switch (SlingLevels.build(_level).time) {
      SlingTime.day => SlingScenes.day,
      SlingTime.sunset => SlingScenes.sunset,
      SlingTime.night => SlingScenes.night,
    };
    // 가로 화면: 게임이 화면 전체를 쓰고, 메뉴는 하늘 위에 띄운다.
    return Scaffold(
      backgroundColor: AppColors.sky,
      // 스택은 항상 화면 전체. (메뉴 줄 크기에 맞춰 줄어들면 게임 화면도 줄어든다)
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: IconTheme.merge(
              data: IconThemeData(color: pal.hud),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: pal.hud),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: '나가기',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      InkWell(
                        onTap: _pickLevel,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xs,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '스테이지 $_level',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: pal.hud,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 20),
                                  if (best > 0) _Stars(count: best, size: 14),
                                ],
                              ),
                              ValueListenableBuilder<int>(
                                valueListenable: _game.score,
                                builder: (_, s, _) => Text(
                                  '$s점 · ${widget.cat.name}와 함께',
                                  style: text.bodySmall?.copyWith(
                                    color: pal.hudMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ValueListenableBuilder<List<SlingShot>>(
                        valueListenable: _game.shots,
                        builder: (_, q, _) => _ShotQueue(shots: q),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _LetterRow(have: _letters),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _game.miceLeft,
                          builder: (_, n, _) => _MiceLeft(count: n),
                        ),
                      ),
                      IconButton(
                        tooltip: '다시 하기',
                        onPressed: () => _start(_level),
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: _sound ? '소리 끄기' : '소리 켜기',
                        onPressed: _toggleSound,
                        icon: Icon(
                          _sound
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 규칙 안내는 빈 하늘 가운데에 (구조물을 가리지 않게)
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showRule ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: const _RuleBanner(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Next { again, next, quit }

/// 남은 고양이 수. 모두 같은 고양이라 아이콘 하나와 숫자로.
class _ShotQueue extends StatelessWidget {
  const _ShotQueue({required this.shots});
  final List<SlingShot> shots;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: AppSpacing.xs),
    padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 2, AppSpacing.sm, 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatIcon(
          tier: SlingShot.standard.tier,
          coat: SlingShot.standard.coat,
          size: 32,
        ),
        Text(
          ' × ${shots.length}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

/// A~F 모으기 현황. 모은 글자는 색이 칠해진다.
class _LetterRow extends StatelessWidget {
  const _LetterRow({required this.have});
  final Set<String> have;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: AppSpacing.xs),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < CatSlingGame.alphabet.length; i++)
          _LetterChip(
            letter: CatSlingGame.alphabet[i],
            color: AppColors.letters[i],
            got: have.contains(CatSlingGame.alphabet[i]),
          ),
      ],
    ),
  );
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.color,
    required this.got,
  });
  final String letter;
  final Color color;
  final bool got;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutBack,
    width: 24,
    height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: got ? color : Colors.transparent,
      shape: BoxShape.circle,
      border: Border.all(
        color: got ? Colors.white : AppColors.muted,
        width: 1.5,
      ),
    ),
    child: Text(
      letter,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: got ? Colors.white : AppColors.muted,
      ),
    ),
  );
}

class _MiceLeft extends StatelessWidget {
  const _MiceLeft({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.pest_control_rodent, color: AppColors.mouse),
      Text(
        ' $count',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ],
  );
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count, required this.size});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < count ? AppColors.star : AppColors.muted,
        ),
    ],
  );
}

class _RuleBanner extends StatelessWidget {
  const _RuleBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      '새총을 뒤로 당겼다 놓으면 발사! 다른 곳을 끌면 맵 이동.\n'
      '날아가는 중에 톡 치면 냥펀치로 돌진해요.\n'
      '⭐ 별을 먹으면 무적! 새에 부딪히면 냥펀치 충전.\n'
      '떠다니는 A~F를 다 모으면 보너스!',
      style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
    ),
  );
}

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({
    required this.top,
    required this.stars,
    required this.current,
  });

  /// 도전 가능한 가장 높은 스테이지.
  final int top;
  final Map<int, int> stars;
  final int current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('스테이지 고르기', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                children: [
                  for (var i = 1; i <= top; i++)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: i == current
                            ? AppColors.tabby.withValues(alpha: 0.15)
                            : null,
                      ),
                      onPressed: () => Navigator.of(context).pop(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$i',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          _Stars(count: stars[i] ?? 0, size: 11),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.level,
    required this.result,
    required this.reward,
    required this.cat,
  });

  final int level;
  final SlingResult result;
  final GameReward reward;
  final Cat cat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cleared = result.cleared;
    return AlertDialog(
      title: Text(cleared ? '스테이지 $level 클리어!' : '쥐가 도망갔어요'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cleared) _Stars(count: result.stars, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text('${result.score}점', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          if (cleared) ...[
            Text('붕어빵 +${reward.bungeoppang}'),
            Text('${cat.name} 경험치 +${reward.catExp}'),
          ] else
            const Text('고양이를 다 썼어요. 다른 각도로 다시 해봐요!'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Next.quit),
          child: const Text('나가기'),
        ),
        if (cleared)
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(_Next.again),
            child: const Text('다시'),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(cleared ? _Next.next : _Next.again),
          child: Text(cleared ? '다음 스테이지' : '다시 하기'),
        ),
      ],
    );
  }
}
