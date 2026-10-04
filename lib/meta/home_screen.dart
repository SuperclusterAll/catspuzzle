import 'package:flutter/material.dart';

import '../core/models/cat.dart';
import '../core/repositories/wallet_repository.dart';
import '../core/save_store.dart';
import '../games/game_catalog.dart';
import '../theme/app_tokens.dart';

/// 메인 메뉴: 재화, 출전 고양이 선택, 게임 목록.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final SaveStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const adoptPrice = 50;

  Map<Currency, int> _balances = const {};
  List<Cat> _cats = const [];
  int? _selectedCatId;

  Cat? get _selected =>
      _cats.where((c) => c.id == _selectedCatId).firstOrNull ??
      _cats.firstOrNull;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final balances = await widget.store.wallet.balances();
    final cats = await widget.store.cats.all();
    if (!mounted) return;
    setState(() {
      _balances = balances;
      _cats = cats;
    });
  }

  Future<void> _adopt() async {
    try {
      final cat = await widget.store.cats.adopt(
        breedId: 'black',
        name: '고양이 ${_cats.length + 1}',
        currency: Currency.bungeoppang,
        price: adoptPrice,
      );
      _selectedCatId = cat.id;
    } on InsufficientFundsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('붕어빵이 부족해요')));
    }
    await _reload();
  }

  Future<void> _play(GameEntry g) async {
    final cat = _selected;
    if (cat == null || g.launch == null) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => g.launch!(widget.store, cat)));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final selected = _selected;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                Expanded(child: Text('catspuzzle', style: text.titleLarge)),
                _Balance(label: '붕어빵', value: _balances[Currency.bungeoppang]),
                const SizedBox(width: AppSpacing.md),
                _Balance(label: 'cash', value: _balances[Currency.cash]),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                    child: Text('함께할 고양이', style: text.titleMedium)),
                TextButton(
                    onPressed: _adopt, child: const Text('입양 · 붕어빵 50')),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in _cats)
                  ChoiceChip(
                    label: Text('${c.name} Lv.${c.level} · ${c.exp}xp'),
                    selected: c.id == selected?.id,
                    onSelected: (_) => setState(() => _selectedCatId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('게임', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final g in gameCatalog)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  enabled: g.launch != null,
                  title: Text(g.title),
                  subtitle: Text(g.blurb),
                  trailing: g.launch != null
                      ? const Icon(Icons.play_arrow)
                      : Text('준비 중',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.muted)),
                  onTap: () => _play(g),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.label, required this.value});
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${value ?? 0}',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: text.bodySmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }
}
