import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../providers/growth_providers.dart';

class GrowthChartsSection extends ConsumerWidget {
  const GrowthChartsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(growthPeriodFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppDimensions.spacingSmall,
          children: [
            _PeriodChip(
              label: '7 days',
              isSelected: selectedPeriod == '7days',
              onTap: () {
                ref.read(growthPeriodFilterProvider.notifier).state = '7days';
              },
            ),
            _PeriodChip(
              label: '30 days',
              isSelected: selectedPeriod == '30days',
              onTap: () {
                ref.read(growthPeriodFilterProvider.notifier).state = '30days';
              },
            ),
            _PeriodChip(
              label: '3 months',
              isSelected: selectedPeriod == '90days',
              onTap: () {
                ref.read(growthPeriodFilterProvider.notifier).state = '90days';
              },
            ),
            _PeriodChip(
              label: '1 year',
              isSelected: selectedPeriod == '1year',
              onTap: () {
                ref.read(growthPeriodFilterProvider.notifier).state = '1year';
              },
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        ref
            .watch(growthAnalyticsProvider(selectedPeriod))
            .when(
              data: (analytics) {
                final points =
                    (analytics['growth_trend'] as List<dynamic>? ?? [])
                        .map((point) => Map<String, dynamic>.from(point as Map))
                        .where((point) => point['average_weight'] is num)
                        .map(
                          (point) => (
                            label: point['week']?.toString() ?? '',
                            value: (point['average_weight'] as num).toDouble(),
                          ),
                        )
                        .toList();
                return _GrowthTrendChart(
                  points: points,
                  recordCount:
                      (analytics['total_records'] as num?)?.toInt() ?? 0,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.3),
      side: BorderSide(
        color: isSelected
            ? AppColors.primaryGreen
            : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _GrowthTrendChart extends StatelessWidget {
  const _GrowthTrendChart({required this.points, required this.recordCount});

  final List<({String label, double value})> points;
  final int recordCount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average weight by week',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$recordCount measurements in this period',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (points.isEmpty)
            const SizedBox(
              height: 170,
              child: Center(
                child: Text('No weight measurements in this period.'),
              ),
            )
          else
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(
                painter: _GrowthTrendPainter(
                  points,
                  Theme.of(context).colorScheme,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GrowthTrendPainter extends CustomPainter {
  const _GrowthTrendPainter(this.points, this.colors);

  final List<({String label, double value})> points;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final values = points.map((point) => point.value);
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final span = maximum == minimum ? 1.0 : maximum - minimum;
    final gridPaint = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = colors.primary;

    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y =
          chart.bottom - ((points[i].value - minimum) / span) * chart.height;
      final point = Offset(x, y);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 4, dotPaint);
    }
    canvas.drawPath(path, linePaint);
    _drawLabel(canvas, minimum.toStringAsFixed(1), Offset(0, chart.bottom - 7));
    _drawLabel(canvas, maximum.toStringAsFixed(1), Offset(0, chart.top - 5));
    if (points.length == 1) {
      _drawLabel(
        canvas,
        points.first.label,
        Offset(chart.center.dx - 20, chart.bottom + 8),
      );
    } else {
      _drawLabel(
        canvas,
        points.first.label,
        Offset(chart.left, chart.bottom + 8),
      );
      _drawLabel(
        canvas,
        points.last.label,
        Offset(chart.right - 44, chart.bottom + 8),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 44);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GrowthTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.colors != colors;
}
