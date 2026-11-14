import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../domain/analytics.dart';

/// Revenue bar chart for daily/weekly/monthly series.
class SalesTrendChart extends StatelessWidget {
  const SalesTrendChart({super.key, required this.points, this.height = 210});

  final List<SeriesPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(0, (m, p) => math.max(m, p.valuePaise));
    if (maxValue == 0) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No sales in this period yet', style: TextStyle(color: AppColors.inkMuted))),
      );
    }
    final maxY = _niceMax(maxValue / 100);
    final labelEvery = points.length > 10 ? (points.length / 7).ceil() : 1;
    final barWidth = points.length > 10 ? 10.0 : 18.0;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value > maxY + 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(Money.compact((value * 100).round()),
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final show = (points.length - 1 - i) % labelEvery == 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(show ? points[i].label : '',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.maroon900,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final p = points[group.x];
                return BarTooltipItem(
                  '${Money.format(p.valuePaise, decimals: false)}\n',
                  const TextStyle(color: AppColors.ivory, fontWeight: FontWeight.w700, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '${p.count} bill${p.count == 1 ? '' : 's'} · ${p.label}',
                      style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: points[i].valuePaise / 100,
                  width: barWidth,
                  color: i == points.length - 1 ? AppColors.gold : AppColors.maroon,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: AppColors.cream),
                ),
              ]),
          ],
        ),
        duration: const Duration(milliseconds: 350),
      ),
    );
  }

  static double _niceMax(double v) {
    if (v <= 0) return 1000;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0]) {
      if (m * exp >= v * 1.08) return m * exp;
    }
    return 10 * exp;
  }
}

/// Horizontal ranking bars (no chart library needed, crisp on any width).
class RankingBars extends StatelessWidget {
  const RankingBars({super.key, required this.entries, this.onTap});

  final List<({String id, String label, String initials, int valuePaise, String caption})> entries;
  final void Function(String id)? onTap;

  @override
  Widget build(BuildContext context) {
    final max = entries.fold<int>(0, (m, e) => math.max(m, e.valuePaise));
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap == null ? null : () => onTap!(entries[i].id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  InitialsAvatar(entries[i].initials, size: 36, highlight: i == 0 && entries[i].valuePaise > 0),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(entries[i].label,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                            ),
                            MoneyText(Money.format(entries[i].valuePaise, decimals: false), size: 14),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: max == 0 ? 0 : entries[i].valuePaise / max),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 7,
                              backgroundColor: AppColors.cream,
                              color: i == 0 ? AppColors.gold : AppColors.maroon,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(entries[i].caption, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Donut chart with legend for payment methods / categories.
class BreakdownDonut extends StatelessWidget {
  const BreakdownDonut({super.key, required this.entries, this.centerLabel});

  final List<BreakdownEntry> entries;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (s, e) => s + e.valuePaise);
    if (total == 0) {
      return const SizedBox(height: 120, child: Center(child: Text('No data', style: TextStyle(color: AppColors.inkMuted))));
    }
    final colors = AppColors.chart;
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      if (entries[i].valuePaise > 0)
                        PieChartSectionData(
                          value: entries[i].valuePaise.toDouble(),
                          color: colors[i % colors.length],
                          radius: 20,
                          showTitle: false,
                        ),
                  ],
                ),
              ),
              if (centerLabel != null)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  MoneyText(Money.compact(total), size: 14, weight: FontWeight.w700),
                  Text(centerLabel!, style: const TextStyle(fontSize: 10, color: AppColors.inkMuted)),
                ]),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entries[i].label,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      ),
                      Text('${(entries[i].valuePaise * 100 / total).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted, fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular target-progress ring.
class TargetRing extends StatelessWidget {
  const TargetRing({super.key, required this.progress, required this.center, this.size = 132, this.onDark = false});

  final double progress;
  final Widget center;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, onDark),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.onDark);
  final double value;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = onDark ? Colors.white.withValues(alpha: 0.12) : AppColors.cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, bg);
    final fg = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [AppColors.goldLight, AppColors.gold, AppColors.goldLight],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    if (value > 0) canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.onDark != onDark;
}
