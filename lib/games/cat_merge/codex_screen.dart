import 'package:flutter/material.dart';

import '../../core/rewards.dart';
import '../../core/save_store.dart';
import '../../theme/app_tokens.dart';
import 'cat_icon.dart';
import 'cat_merge_game.dart';
import 'cat_tiers.dart';

/// 냥냥 합체 도감: 품종(행) × 털색(열).
class CodexScreen extends StatefulWidget {
  const CodexScreen({super.key, required this.store});
  final SaveStore store;

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  Set<String>? _found;

  @override
  void initState() {
    super.initState();
    widget.store.codex.entries(CatMergeGame.id).then((f) {
      if (mounted) setState(() => _found = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final found = _found ?? const {};
    final count = [
      for (var t = 0; t < catTiers.length; t++)
        for (final c in CatCoat.values)
          if (found.contains(codexId(t, c))) 1,
    ].length;
    return Scaffold(
      appBar: AppBar(title: Text('도감 $count / $codexTotal')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
              '처음 만나는 고양이는 붕어빵 ${RewardPolicy.codexCommon}개, '
              '희귀 털색(★)은 ${RewardPolicy.codexRare}개',
              style: text.bodyMedium?.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSpacing.md),
          for (var t = 0; t < catTiers.length; t++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(catTiers[t].name,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  for (final c in CatCoat.values)
                    Expanded(
                      child: _CoatCell(
                        tier: t,
                        coat: c,
                        found: found.contains(codexId(t, c)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CoatCell extends StatelessWidget {
  const _CoatCell({required this.tier, required this.coat, required this.found});
  final int tier;
  final CatCoat coat;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = catTiers[tier].coatName(coat);
    return Column(
      children: [
        CatIcon(tier: tier, coat: coat, size: 52, silhouette: !found),
        const SizedBox(height: AppSpacing.xs),
        Text(
          found ? (coat.isRare ? '★ $name' : name) : '???',
          style: text.labelSmall?.copyWith(
              color: coat.isRare ? AppColors.star : AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
