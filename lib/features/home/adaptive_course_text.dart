import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fits metadata into the existing slot geometry. No timetable dimensions change.
class AdaptiveCourseText extends StatelessWidget {
  const AdaptiveCourseText({
    super.key,
    required this.title,
    required this.metadata,
    required this.titleColor,
    required this.metaColor,
  });
  final String title;
  final List<String> metadata;
  final Color titleColor;
  final Color metaColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
    child: LayoutBuilder(
      builder: (context, box) {
        final texts = [
          title,
          ...metadata.where((text) => text.trim().isNotEmpty),
        ];
        final scaler = MediaQuery.textScalerOf(context);
        final base = DefaultTextStyle.of(context).style;
        final direction = Directionality.of(context);
        List<TextStyle> styles = [];
        List<int> desired = [];
        List<double> heights = [];
        final gap = texts.length > 1 ? 2.0 : 0.0;
        // Prefer the original readable sizes; only compact when the slot is short.
        for (final factor in [1.0, .94, .88]) {
          styles = [
            for (var i = 0; i < texts.length; i++)
              base.copyWith(
                color: i == 0 ? titleColor : metaColor,
                fontSize: (i == 0 ? 11.5 : 10) * factor,
                fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                height: 1.15,
              ),
          ];
          desired = [];
          heights = [];
          for (var i = 0; i < texts.length; i++) {
            final painter = TextPainter(
              text: TextSpan(text: texts[i], style: styles[i]),
              textScaler: scaler,
              textDirection: direction,
            )..layout(maxWidth: box.maxWidth);
            final lines = painter.computeLineMetrics();
            desired.add(math.max(1, lines.length));
            heights.add(
              lines.isEmpty
                  ? painter.preferredLineHeight
                  : lines.map((l) => l.height).reduce(math.max),
            );
            painter.dispose();
          }
          final needed = List.generate(
            texts.length,
            (i) => desired[i] * heights[i],
          ).fold<double>(gap, (a, b) => a + b);
          if (needed <= box.maxHeight) break;
        }
        final allocated = List.filled(texts.length, 1);
        var remaining =
            box.maxHeight - gap - heights.fold<double>(0, (a, b) => a + b);
        // Give every field a line before allocating extra lines in reading order.
        var changed = true;
        while (changed) {
          changed = false;
          for (var i = 0; i < texts.length; i++) {
            if (allocated[i] < desired[i] && remaining >= heights[i]) {
              allocated[i]++;
              remaining -= heights[i];
              changed = true;
            }
          }
        }
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < texts.length; i++) ...[
              if (i == 1) SizedBox(height: gap),
              Text(
                texts[i],
                maxLines: allocated[i],
                overflow: TextOverflow.ellipsis,
                style: styles[i],
              ),
            ],
          ],
        );
        // With all optional fields enabled even one line per field can exceed
        // a one-section card. Scale the complete text block inside its slot.
        if (heights.fold<double>(gap, (a, b) => a + b) > box.maxHeight) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(width: box.maxWidth, child: content),
          );
        }
        return content;
      },
    ),
  );
}
