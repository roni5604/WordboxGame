import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/home/map/map_layout.dart';
import 'package:wordbox_hebrew/features/home/map/sky_ladder.dart';

void main() {
  final layout = CampaignMapLayout.campaign;

  test('הסולם לשמיים נמצא אחרי השלב האחרון, בסוף השביל', () {
    expect(layout.skyLadderU, layout.lastU + CampaignMapLayout.ladderGap);
    expect(layout.skyLadderU, greaterThan(layout.lastU));
  });

  test('אחרי השלב האחרון השביל מתעקל אל מרכז הסולם', () {
    expect(layout.roadLateral(layout.skyLadderU), closeTo(0, 1e-9));
    // השביל עדיין עובר בדיוק דרך השלב האחרון.
    expect(layout.roadLateral(layout.lastU), closeTo(layout.nodes.last.lateral, 1e-9));
  });

  test('רחבת הסולם נקייה מקישוטים קטנים על השביל', () {
    final nearPad = layout.props.where(
      (p) => (p.u - layout.skyLadderU).abs() < 220 && p.lateral.abs() < 0.7,
    );
    expect(nearPad, isEmpty);
  });

  testWidgets('הסולם והשלט מוצגים עם הטקסטים', (tester) async {
    final ambient = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 40));
    addTearDown(ambient.dispose);
    var tapped = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkyLadder(ambient: ambient, onTap: () => tapped++),
              LadderSign(ambient: ambient),
            ],
          ),
        ),
      ),
    );
    expect(find.text('העולם הבא · בקרוב'), findsOneWidget);
    expect(find.text('שלבים חדשים בדרך!'), findsOneWidget);
    await tester.tap(find.byType(SkyLadder));
    expect(tapped, 1);
  });
}
