import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/items.dart';
import '../../core/models/cat.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/rewards.dart';
import '../../core/save_store.dart';
import '../../theme/app_tokens.dart';
import 'cat_icon.dart';
import 'cat_merge_game.dart';
import 'cat_tiers.dart';
import 'codex_screen.dart';
import 'merge_items.dart';
import 'merge_sfx.dart';

/// 냥냥 합체 (항상 무한 모드).
///
/// 끝나는 조건
///  - 고양이가 빨간 선 위에 3초 머물면 끝 (가운데에 3·2·1이 뜬다)
///  - 깃발 버튼으로 직접 그만두기 (지금까지 점수로 보상)
class CatMergeScreen extends StatefulWidget {
  const CatMergeScreen({super.key, required this.store, required this.cat});

  final SaveStore store;
  final Cat cat;

  @override
  State<CatMergeScreen> createState() => _CatMergeScreenState();
}

class _CatMergeScreenState extends State<CatMergeScreen> {
  late final CatMergeGame _game = CatMergeGame(
    onEnd: _onEnd,
    onSpawn: _onSpawn,
    withPartner: true,
  );

  int _best = 0;
  final _codex = <String>{};
  Map<ItemId, int> _items = const {};
  bool _sound = true;
  bool _showRule = true;

  SaveStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _load();
    Sfx.load();
    _hideRuleLater();
  }

  void _hideRuleLater() {
    setState(() => _showRule = true);
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _showRule = false);
    });
  }

  Future<void> _load() async {
    final best = await _store.progress.bestScore(CatMergeGame.id);
    final codex = await _store.codex.entries(CatMergeGame.id);
    final items = await _store.inventory.counts();
    final sound =
        await _store.settings.getBool(SettingsRepository.soundOn, fallback: true);
    if (!mounted) return;
    Sfx.enabled = sound;
    setState(() {
      _best = best;
      _codex.addAll(codex);
      _items = items;
      _sound = sound;
    });
  }

  Future<void> _toggleSound() async {
    final on = !_sound;
    Sfx.enabled = on;
    setState(() => _sound = on);
    await _store.settings.setBool(SettingsRepository.soundOn, on);
  }

  void _onSpawn(int tier, CatCoat coat) {
    final id = codexId(tier, coat);
    if (!_codex.add(id)) return;
    // 목록을 아직 못 읽었어도 DB가 중복을 걸러주므로 보상은 한 번만 나간다.
    _store.discover(CatMergeGame.id, id, rare: coat.isRare).then((fish) {
      if (fish == 0 || !mounted) return;
      Sfx.codex();
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1400),
        content: Text('${coat.isRare ? '★ ' : ''}도감 등록 · '
            '${catTiers[tier].coatName(coat)} ${catTiers[tier].name}  붕어빵 +$fish'),
      ));
    });
  }

  Future<void> _tapItem(ItemId item) async {
    if ((_items[item] ?? 0) == 0) {
      await _offerBuy(item);
      return;
    }
    if (!_game.canUseItem) return;
    if (!await _store.inventory.consume(item)) return;
    // 기다리는 사이 이미 떨어뜨렸으면 되돌려준다.
    if (!_game.useItem(item)) await _store.inventory.add(item, 1);
    await _refreshItems();
  }

  Future<void> _refreshItems() async {
    final items = await _store.inventory.counts();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _offerBuy(ItemId item) async {
    final fish = await _store.wallet.balance(Currency.bungeoppang);
    if (!mounted) return;
    final buy = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _BuySheet(item: item, balance: fish),
    );
    if (buy != true) return;
    try {
      await _store.buyItem(item);
    } on InsufficientFundsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('붕어빵이 부족해요')));
    }
    await _refreshItems();
  }

  Future<void> _confirmGiveUp() async {
    if (_game.isOver) return;
    _game.pauseEngine();
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이번 판을 끝낼까요?'),
        content: Text('지금까지 ${_game.score.value}점으로 보상을 받아요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속하기')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('끝내기')),
        ],
      ),
    );
    _game.resumeEngine();
    if (quit == true) _game.giveUp();
  }

  Future<void> _openCodex() async {
    _game.pauseEngine();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CodexScreen(store: _store)));
    _game.resumeEngine();
  }

  Future<void> _onEnd(RunResult r) async {
    final reward = await _store.finishPlay(
        gameId: CatMergeGame.id, score: r.score, catId: widget.cat.id);
    final isBest = r.score > _best;
    if (!mounted) return;
    if (isBest) setState(() => _best = r.score);
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
          result: r, isBest: isBest, reward: reward, cat: widget.cat),
    );
    if (!mounted) return;
    if (again == true) {
      _game.restart();
      _hideRuleLater();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '나가기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _game.score,
                          builder: (_, s, _) => Text('$s',
                              style: text.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        Text('최고 $_best · ${widget.cat.name}와 함께',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Text('다음',
                      style: text.bodySmall?.copyWith(color: AppColors.muted)),
                  const SizedBox(width: AppSpacing.sm),
                  ValueListenableBuilder<DropSpec>(
                    valueListenable: _game.next,
                    builder: (_, s, _) => DropIcon(spec: s, size: 44),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GameWidget(game: _game),
                  // 연쇄 배지
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.md,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _game.chain,
                      builder: (_, n, _) => _ChainBadge(chain: n),
                    ),
                  ),
                  // 넘침 카운트다운
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _game.countdown,
                        builder: (_, n, _) => _Countdown(value: n),
                      ),
                    ),
                  ),
                  // 시작할 때 규칙 안내
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showRule ? 1 : 0,
                        duration: const Duration(milliseconds: 400),
                        child: const _RuleBanner(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  for (final item in ItemId.values) ...[
                    _ItemButton(
                        item: item,
                        count: _items[item] ?? 0,
                        onTap: () => _tapItem(item)),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: '도감',
                    onPressed: _openCodex,
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
                  IconButton(
                    tooltip: _sound ? '소리 끄기' : '소리 켜기',
                    onPressed: _toggleSound,
                    icon: Icon(_sound
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined),
                  ),
                  IconButton(
                    tooltip: '그만하기',
                    onPressed: _confirmGiveUp,
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
              ),
            ),
            const _EvolutionStrip(),
          ],
        ),
      ),
    );
  }
}

class _ChainBadge extends StatelessWidget {
  const _ChainBadge({required this.chain});
  final int chain;

  @override
  Widget build(BuildContext context) {
    final show = chain >= 2;
    final hot = chain >= 4;
    return AnimatedScale(
      scale: show ? 1 : 0.4,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: hot ? const Color(0xFFFFC53D) : const Color(0xFFFF5C8A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            '연쇄 x$chain',
            style: TextStyle(
              color: hot ? const Color(0xFF7A3E00) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    if (value == 0) return const SizedBox.shrink();
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: 1.6, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Outlined('$value', size: 96, color: AppColors.danger),
            const _Outlined('넘쳐요!', size: 28, color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined(this.text, {required this.size, required this.color});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Text(text,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.16
                  ..strokeJoin = StrokeJoin.round
                  ..color = Colors.white,
              )),
          Text(text,
              style: TextStyle(
                  fontSize: size, fontWeight: FontWeight.w900, color: color)),
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
          '같은 고양이끼리 닿으면 합체!\n'
          '빨간 선 위에 고양이가 3초 머물면 끝나요.',
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
      );
}

class _ItemButton extends StatelessWidget {
  const _ItemButton(
      {required this.item, required this.count, required this.onTap});
  final ItemId item;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
        icon: ItemIcon(item: item, size: 24),
        label: Text(count > 0 ? '$count' : '+'),
      );
}

class _BuySheet extends StatelessWidget {
  const _BuySheet({required this.item, required this.balance});
  final ItemId item;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ItemIcon(item: item, size: 40),
              const SizedBox(width: AppSpacing.md),
              Text(item.label, style: text.titleLarge),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(item.description),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: balance >= item.price
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text('붕어빵 ${item.price}개로 사기 (보유 $balance)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            const OutlinedButton(
              onPressed: null,
              child: Text('광고 보고 1개 받기 · 준비 중'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 합체 순서 안내.
class _EvolutionStrip extends StatelessWidget {
  const _EvolutionStrip();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < catTiers.length; i++)
              CatIcon(tier: i, size: 16 + i * 1.6),
          ],
        ),
      );
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.result,
    required this.isBest,
    required this.reward,
    required this.cat,
  });

  final RunResult result;
  final bool isBest;
  final GameReward reward;
  final Cat cat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = isBest
        ? '최고 기록!'
        : result.gaveUp
            ? '수고했어요'
            : '상자가 넘쳤어요';
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.score}점', style: text.displaySmall),
          if (result.bestTier >= 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              CatIcon(tier: result.bestTier, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Text('최고 합체: ${catTiers[result.bestTier].name}'),
            ]),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('붕어빵 +${reward.bungeoppang}'),
          Text('${cat.name} 경험치 +${reward.catExp}'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('나가기')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('다시 하기')),
      ],
    );
  }
}
