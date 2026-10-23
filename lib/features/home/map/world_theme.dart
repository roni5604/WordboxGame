import 'package:flutter/material.dart';

/// החיה החוקרת שמלווה את זואי בכל עולם (ראו explorer_critters.dart).
enum ExplorerKind { bunny, frog, bee, owl, penguin }

/// סגנון הגבעות שבאופק - כל עולם "נראה" אחרת גם מרחוק.
enum HorizonStyle { hills, dunes, blossomHills, treeline, peaks }

/// סוגי הקישוטים שבצדי השביל (מצוירים בקוד, בלי נכסי אמנות).
enum PropKind { sprout, flower, bush, mushroom, roundTree, reeds, rock, lilyPond, sunflower, blossomTree, pine, lantern, crystal, snowPine }

/// פלטה ותפאורה מלאה של עולם אחד במפת השלבים: שמיים, קרקע, שביל, נהר
/// הכניסה אליו, קישוטים והחיה החוקרת. כל עולם הוא "רמה" נפרדת בנוף -
/// בהשראת מפות שלבים תלת-ממדיות במשחקי פאזל, אבל בזהות של זואי הבלשית.
class WorldTheme {
  /// שמיים מלמעלה לאופק.
  final List<Color> sky;
  final Color groundFar;
  final Color groundNear;
  final Color road;
  final Color roadEdge;

  /// הנהר הזוהר שחוצים כדי להיכנס לעולם הזה.
  final Color water;
  final Color waterGlow;

  /// צבע הגחליליות / אבקת הפרחים / הבועות שמרחפות מעל העולם.
  final Color sparkle;

  /// צבע "חתימה" של העולם - לכרטיס הכניסה, לשלט ולכותרת.
  final Color accent;
  final bool night;
  final HorizonStyle horizon;
  final List<PropKind> props;
  final ExplorerKind explorer;

  /// שם החיה החוקרת (לנגישות ולכרטיס הכניסה), ומין דקדוקי לניסוח.
  final String explorerNameHe;
  final bool explorerFeminine;

  const WorldTheme({
    required this.sky,
    required this.groundFar,
    required this.groundNear,
    required this.road,
    required this.roadEdge,
    required this.water,
    required this.waterGlow,
    required this.sparkle,
    required this.accent,
    required this.night,
    required this.horizon,
    required this.props,
    required this.explorer,
    required this.explorerNameHe,
    required this.explorerFeminine,
  });

  static const List<WorldTheme> all = [
    // נבטים - בוקר אפרסקי ואחו ירוק-רענן.
    WorldTheme(
      sky: [Color(0xFFFF8E72), Color(0xFFFFB58F), Color(0xFFFFE2B8)],
      groundFar: Color(0xFFB4E37A),
      groundNear: Color(0xFF58B84E),
      road: Color(0xFFFFF1CC),
      roadEdge: Color(0xFFE2C98E),
      water: Color(0xFF4FC3F7),
      waterGlow: Color(0xFFB3ECFF),
      sparkle: Color(0xFFFFF4A8),
      accent: Color(0xFFFF7A59),
      night: false,
      horizon: HorizonStyle.hills,
      props: [PropKind.sprout, PropKind.flower, PropKind.bush, PropKind.mushroom, PropKind.roundTree],
      explorer: ExplorerKind.bunny,
      explorerNameHe: 'הארנבת החוקרת',
      explorerFeminine: true,
    ),
    // ניצנים - עולם המים: טורקיז, סגול, בריכות וקני סוף.
    WorldTheme(
      sky: [Color(0xFF6A4BD6), Color(0xFF4F9BEA), Color(0xFFB0EEFF)],
      groundFar: Color(0xFF7FE0DE),
      groundNear: Color(0xFF2E9DB6),
      road: Color(0xFFE6FBFF),
      roadEdge: Color(0xFF9AD6E4),
      water: Color(0xFF9B5CF6),
      waterGlow: Color(0xFFE7C4FF),
      sparkle: Color(0xFFD6FDFF),
      accent: Color(0xFF7C4DFF),
      night: false,
      horizon: HorizonStyle.dunes,
      props: [PropKind.reeds, PropKind.lilyPond, PropKind.rock, PropKind.bush, PropKind.flower],
      explorer: ExplorerKind.frog,
      explorerNameHe: 'הצפרדע הבלשית',
      explorerFeminine: true,
    ),
    // פריחה - שמיים זהובים ואחו ורוד מלא פרחים.
    WorldTheme(
      sky: [Color(0xFFFF7A6B), Color(0xFFFFB347), Color(0xFFFFEBA8)],
      groundFar: Color(0xFFFFC9D6),
      groundNear: Color(0xFFEC7FA6),
      road: Color(0xFFFFF7E6),
      roadEdge: Color(0xFFF2C4A9),
      water: Color(0xFF2EC4D6),
      waterGlow: Color(0xFFB8FFF6),
      sparkle: Color(0xFFFFFFFF),
      accent: Color(0xFFF37335),
      night: false,
      horizon: HorizonStyle.blossomHills,
      props: [PropKind.sunflower, PropKind.blossomTree, PropKind.flower, PropKind.bush],
      explorer: ExplorerKind.bee,
      explorerNameHe: 'הדבורה הסקרנית',
      explorerFeminine: true,
    ),
    // היער הגדול - שעת דמדומים, אורנים, פטריות ופנסים.
    WorldTheme(
      sky: [Color(0xFF0E2F4F), Color(0xFF1B6478), Color(0xFF86E3C4)],
      groundFar: Color(0xFF3DAA7C),
      groundNear: Color(0xFF145F48),
      road: Color(0xFFD3F0DC),
      roadEdge: Color(0xFF86C3A0),
      water: Color(0xFF7B5CFF),
      waterGlow: Color(0xFFD9C8FF),
      sparkle: Color(0xFFEFFF8A),
      accent: Color(0xFF11998E),
      night: true,
      horizon: HorizonStyle.treeline,
      props: [PropKind.pine, PropKind.roundTree, PropKind.mushroom, PropKind.lantern, PropKind.pine],
      explorer: ExplorerKind.owl,
      explorerNameHe: 'הינשוף הבלש',
      explorerFeminine: false,
    ),
    // פסגת המילים - לילה סגול, סלעים, קריסטלים ושלג.
    WorldTheme(
      sky: [Color(0xFF17113F), Color(0xFF3A2C8C), Color(0xFF93A6FF)],
      groundFar: Color(0xFF9C8CE8),
      groundNear: Color(0xFF4B3DA6),
      road: Color(0xFFEDEBFF),
      roadEdge: Color(0xFFB6ACF2),
      water: Color(0xFF3FD0FF),
      waterGlow: Color(0xFFCBF6FF),
      sparkle: Color(0xFFFFFFFF),
      accent: Color(0xFF6A11CB),
      night: true,
      horizon: HorizonStyle.peaks,
      props: [PropKind.rock, PropKind.crystal, PropKind.snowPine, PropKind.lantern],
      explorer: ExplorerKind.penguin,
      explorerNameHe: 'הפינגווין המגלה',
      explorerFeminine: false,
    ),
  ];

  static WorldTheme of(int worldIndex) => all[worldIndex % all.length];

  /// מעבר רך בין שני עולמות (לשמיים כשחוצים נהר).
  static List<Color> lerpSky(WorldTheme a, WorldTheme b, double t) =>
      [for (int i = 0; i < a.sky.length; i++) Color.lerp(a.sky[i], b.sky[i], t)!];
}
