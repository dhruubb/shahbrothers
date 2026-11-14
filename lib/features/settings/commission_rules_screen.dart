import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/bonus_calculator.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

/// Owner edits the bonus slabs.
class CommissionRulesScreen extends ConsumerStatefulWidget {
  const CommissionRulesScreen({super.key});

  @override
  ConsumerState<CommissionRulesScreen> createState() => _CommissionRulesScreenState();
}

class _RuleDraft {
  _RuleDraft(CommissionRule r)
      : id = r.id,
        name = TextEditingController(text: r.name),
        threshold = TextEditingController(text: _n(r.minAchievementPct)),
        pct = TextEditingController(text: _n(r.commissionPct)),
        flat = TextEditingController(text: r.flatBonusPaise == 0 ? '' : '${r.flatBonusPaise ~/ 100}'),
        active = r.isActive;

  final String id;
  final TextEditingController name, threshold, pct, flat;
  bool active;

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  CommissionRule toRule() => CommissionRule(
        id: id,
        name: name.text.trim(),
        minAchievementPct: double.tryParse(threshold.text) ?? -1,
        commissionPct: double.tryParse(pct.text) ?? -1,
        flatBonusPaise: Money.parse(flat.text) ?? 0,
        isActive: active,
      );

  void dispose() {
    for (final c in [name, threshold, pct, flat]) {
      c.dispose();
    }
  }
}

class _CommissionRulesScreenState extends ConsumerState<CommissionRulesScreen> {
  List<_RuleDraft>? _rules;
  bool _saving = false;
  final _sampleTarget = 15000000; // ₹1.5L for the preview

  @override
  void dispose() {
    for (final r in _rules ?? const <_RuleDraft>[]) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).saveCommissionRules(_rules!.map((r) => r.toRule()).toList());
      ref.refreshData();
      if (mounted) {
        showSnack(context, 'Bonus rules saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(commissionRulesProvider);
    if (_rules == null && async.hasValue) {
      _rules = async.value!.map(_RuleDraft.new).toList();
    }
    final rules = _rules;

    return Scaffold(
      appBar: AppBar(title: const Text('Bonus rules')),
      body: rules == null
          ? AsyncView<List<CommissionRule>>(value: async, builder: (_) => const SizedBox.shrink())
          : MaxWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Text(
                    'Each month, a salesperson\'s net sales (excl. GST) are compared with their target. '
                    'The highest active slab reached sets the commission on all net sales, plus its flat bonus.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < rules.length; i++) _ruleCard(rules[i], i),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => rules.add(_RuleDraft(const CommissionRule(
                          id: '',
                          name: 'New slab',
                          minAchievementPct: 150,
                          commissionPct: 3,
                        )))),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add slab'),
                  ),
                  const SectionHeader('Preview'),
                  _Preview(rules: rules.map((r) => r.toRule()).toList(), target: _sampleTarget),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ivory))
                        : const Text('Save rules'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _ruleCard(_RuleDraft r, int index) {
    final fmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: AppTextField(controller: r.name, label: 'Slab name', dense: true, onChanged: (_) => setState(() {})),
          ),
          Switch(value: r.active, onChanged: (v) => setState(() => r.active = v)),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => setState(() {
              _rules!.removeAt(index).dispose();
            }),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: AppTextField(
              controller: r.threshold,
              label: 'From target %',
              dense: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: fmt,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              controller: r.pct,
              label: 'Commission %',
              dense: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: fmt,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              controller: r.flat,
              label: 'Flat ₹',
              dense: true,
              keyboardType: TextInputType.number,
              inputFormatters: fmt,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.rules, required this.target});
  final List<CommissionRule> rules;
  final int target;

  @override
  Widget build(BuildContext context) {
    final valid = rules.where((r) => r.minAchievementPct >= 0 && r.commissionPct >= 0).toList();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('For a ${Money.compact(target)} monthly target:', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final pct in [50, 80, 100, 120, 150])
          Builder(builder: (context) {
            final base = target * pct ~/ 100;
            final r = BonusCalculator.compute(basePaise: base, targetPaise: target, rules: valid);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 56, child: Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text('${Money.compact(base)} sales · ${r.rule?.name ?? 'none'}', style: const TextStyle(color: AppColors.inkMuted))),
                MoneyText(Money.format(r.totalPaise, decimals: false), size: 14),
              ]),
            );
          }),
      ]),
    );
  }
}
