// מייצר דף תצוגה של כל הדמויות: flutter test test/tools/avatar_sheet_test.dart
// (רק כשמוגדר AVATAR_SHEET=path - לא חלק מהבדיקות הרגילות).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/profile/avatars/avatar_catalog.dart';

void main() {
  final out = Platform.environment['AVATAR_SHEET'];
  testWidgets('avatar sheet', (tester) async {
    if (out == null) return;
    final key = GlobalKey();
    const cols = 10;
    const cell = 120.0;
    final rows = (kPaintedAvatars.length / cols).ceil();
    tester.view.physicalSize = Size(cols * cell, rows * cell);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF4A1A9C),
          child: Wrap(
            textDirection: TextDirection.ltr,
            children: [
              for (final a in kPaintedAvatars)
                SizedBox(
                  width: cell,
                  height: cell,
                  child: Padding(padding: const EdgeInsets.all(6), child: CustomPaint(painter: a.painter)),
                ),
            ],
          ),
        ),
      ),
    );
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
