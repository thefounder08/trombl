import 'package:flutter/material.dart';

/// Trombl's spacing scale — use these instead of magic numbers.
///
/// Based on an 4-pt base grid. Every value is a multiple of 4.
/// The non-standard 22 is the canonical horizontal screen margin
/// carried over from the prototype (matches the 22px gutter).
abstract final class TromblSpacing {
  /// 4 pt — micro gap (icon padding, tag inner padding)
  static const double xs  = 4;

  /// 8 pt — tight gap (between inline elements, tag rows)
  static const double sm  = 8;

  /// 12 pt — small gap (between list items, label-to-field)
  static const double md  = 12;

  /// 16 pt — standard gap (card padding, section gap)
  static const double lg  = 16;

  /// 22 pt — screen horizontal margin (matches prototype gutter)
  static const double screenH = 22;

  /// 28 pt — large section gap (between content blocks)
  static const double xl  = 28;

  /// 40 pt — extra large (response screen vertical breathing room)
  static const double xxl = 40;
}

/// Convenience EdgeInsets helpers that map to the spacing scale.
abstract final class TromblInsets {
  /// Standard screen padding — 22 h, no vertical.
  static const screen = EdgeInsets.symmetric(horizontal: TromblSpacing.screenH);

  /// Card inner padding — 16 all sides.
  static const card = EdgeInsets.all(TromblSpacing.lg);

  /// Compact card — 14 v / 16 h.
  static const cardCompact = EdgeInsets.symmetric(
    horizontal: TromblSpacing.lg, vertical: 14,
  );

  /// Standard list tile — 14 v / 16 h (matches existing option rows).
  static const listTile = EdgeInsets.symmetric(
    horizontal: TromblSpacing.lg, vertical: 14,
  );

  /// Bottom sheet — 14 top, 22 sides, 28+ bottom.
  static EdgeInsets sheet(BuildContext context) => EdgeInsets.fromLTRB(
    TromblSpacing.screenH,
    14,
    TromblSpacing.screenH,
    MediaQuery.of(context).padding.bottom + TromblSpacing.xl,
  );
}
