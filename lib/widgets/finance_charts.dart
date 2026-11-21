import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';

/// Animated circular progress gauge inspired by minimalist sage/mint rings.
class CircularFinanceRing extends StatelessWidget {
  const CircularFinanceRing({
    super.key,
    required this.progress,
    required this.centerValue,
    required this.centerLabel,
    this.size = 118,
    this.strokeWidth = 10,
    this.progressColor,
    this.trackColor,
  });

  final double progress;
  final String centerValue;
  final String centerLabel;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = progressColor ?? g.primary;
    final bg = trackColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.1)
            : g.primary.withValues(alpha: 0.14));

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) {
          return CustomPaint(
            painter: _RingPainter(
              progress: animatedProgress,
              progressColor: fg,
              trackColor: bg,
              strokeWidth: strokeWidth,
              glow: dark,
            ),
            child: child,
          );
        },
        child: Padding(
          padding: EdgeInsets.all(strokeWidth + 8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: g.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  centerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: g.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.glow,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (glow) {
      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);
    }

    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glow != glow;
  }
}

/// Single monthly data point for [MonthlyBarChart].
class MonthlyChartPoint {
  const MonthlyChartPoint({
    required this.shortLabel,
    required this.fullLabel,
    required this.received,
    required this.upcoming,
  });

  final String shortLabel;
  final String fullLabel;
  final double received;
  final double upcoming;

  double get total => received + upcoming;
}

/// Animated rounded vertical bar chart with tap-to-inspect monthly breakdown.
class MonthlyBarChart extends StatefulWidget {
  const MonthlyBarChart({
    super.key,
    required this.points,
    required this.formatAmount,
    this.height = 170,
  });

  final List<MonthlyChartPoint> points;
  final String Function(double) formatAmount;
  final double height;

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = widget.points.fold<double>(
      0,
      (prev, item) => math.max(prev, item.total),
    );

    if (maxValue <= 0) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Add entries in this year to see monthly flow.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: g.textSecondary,
                ),
          ),
        ),
      );
    }

    final activeIndex = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < widget.points.length
        ? _selectedIndex!
        : null;
    final selectedPoint =
        activeIndex != null ? widget.points[activeIndex] : null;

    final receivedColor = g.primary;
    final upcomingTrackColor = dark
        ? Colors.white.withValues(alpha: 0.14)
        : g.primary.withValues(alpha: 0.16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedPoint != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: g.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: g.border),
            ),
            child: Row(
              children: [
                Text(
                  selectedPoint.fullLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Text(
                  'Rec: ${widget.formatAmount(selectedPoint.received)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: g.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (selectedPoint.upcoming > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Up: ${widget.formatAmount(selectedPoint.upcoming)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: g.warning,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _LegendDot(color: receivedColor, label: 'Received'),
                const SizedBox(width: 14),
                _LegendDot(color: upcomingTrackColor, label: 'Upcoming'),
                const Spacer(),
                Text(
                  'Tap bar to inspect',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: g.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const labelHeight = 22.0;
              final barAreaHeight = constraints.maxHeight - labelHeight - 6;

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, anim, _) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(widget.points.length, (i) {
                      final point = widget.points[i];
                      final totalFraction =
                          (point.total / maxValue).clamp(0.0, 1.0) * anim;
                      final receivedFraction = point.total > 0
                          ? (point.received / point.total).clamp(0.0, 1.0)
                          : 0.0;
                      final totalBarH = math.max(
                        point.total > 0 ? 8.0 : 4.0,
                        barAreaHeight * totalFraction,
                      );
                      final receivedBarH = totalBarH * receivedFraction;
                      final isSelected = activeIndex == i;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedIndex = isSelected ? null : i;
                            });
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isSelected ? 14 : 11,
                                    height: totalBarH,
                                    decoration: BoxDecoration(
                                      color: point.total > 0
                                          ? upcomingTrackColor
                                          : g.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(6),
                                      border: isSelected
                                          ? Border.all(
                                              color: g.primary,
                                              width: 1.4,
                                            )
                                          : null,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: point.received > 0
                                        ? Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              width: double.infinity,
                                              height: receivedBarH,
                                              decoration: BoxDecoration(
                                                color: receivedColor,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: labelHeight,
                                child: Text(
                                  point.shortLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? g.primary
                                            : g.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.glass.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Segment data model for [CategoryDonutChart].
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Multi-segment animated category donut chart with clean legend rows.
class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({
    super.key,
    required this.segments,
    required this.centerValue,
    required this.centerLabel,
    this.size = 136,
    this.strokeWidth = 18,
  });

  final List<DonutSegment> segments;
  final String centerValue;
  final String centerLabel;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final nonZero = segments.where((s) => s.value > 0).toList();
    final total = nonZero.fold<double>(0, (sum, s) => sum + s.value);

    final adaptedSegments = nonZero
        .map(
          (s) => DonutSegment(
            label: s.label,
            value: s.value,
            color: AppColors.adaptiveColor(s.color, dark),
          ),
        )
        .toList();

    final donut = SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          return CustomPaint(
            painter: _DonutPainter(
              segments: adaptedSegments,
              total: total,
              progress: progress,
              strokeWidth: strokeWidth,
              emptyTrackColor: g.surfaceSubtle,
            ),
            child: child,
          );
        },
        child: Padding(
          padding: EdgeInsets.all(strokeWidth + 8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerValue,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: g.textPrimary,
                        ),
                  ),
                ),
                Text(
                  centerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: g.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: adaptedSegments.take(5).map((seg) {
        final pct = total > 0 ? (seg.value / total * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: seg.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  seg.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: g.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: g.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              donut,
              const SizedBox(height: AppSpacing.md),
              legend,
            ],
          );
        }
        return Row(
          children: [
            donut,
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.strokeWidth,
    required this.emptyTrackColor,
  });

  final List<DonutSegment> segments;
  final double total;
  final double progress;
  final double strokeWidth;
  final Color emptyTrackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    if (segments.isEmpty || total <= 0) {
      final trackPaint = Paint()
        ..color = emptyTrackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, trackPaint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gap = segments.length > 1 ? 0.035 : 0.0;
    var startAngle = -math.pi / 2;

    for (final seg in segments) {
      final rawSweep = 2 * math.pi * (seg.value / total) * progress;
      final sweep = math.max(0.0, rawSweep - gap);
      if (sweep > 0.002) {
        final paint = Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(rect, startAngle + gap / 2, sweep, false, paint);
      }
      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.total != total ||
        oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.emptyTrackColor != emptyTrackColor;
  }
}
