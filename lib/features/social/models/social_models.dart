import 'package:equatable/equatable.dart';

/// מצב נוכחות של שחקן/ית, כפי שמוצג לחברים.
enum PresenceStatus { online, playing, offline }

/// "כרטיס ציבורי" של שחקן/ית - המידע שחברים (ושחקנים בחדר) יכולים לראות:
/// שם, אוואטאר, קוד חבר, התקדמות ונוכחות. נשמר ב-publicProfiles/{uid}.
///
/// הפרופיל המלא (מטבעות, רמזים, התקדמות מפורטת) נשאר פרטי ב-players/{uid}.
class PublicProfile extends Equatable {
  /// כמה זמן אחרי פעימת הנוכחות האחרונה עדיין נחשבים "מחוברים".
  static const onlineWindow = Duration(seconds: 150);

  final String uid;
  final String displayName;
  final String avatarId;
  final String? photoUrl;
  final String friendCode;
  final int totalStars;
  final int highestLevel;
  final int mpGames;
  final int mpWins;
  final DateTime? lastActive;
  final PresenceStatus status;

  /// האתגר היומי האחרון ששוחק: תאריך (yyyy-MM-dd), ניקוד ורצף ימים.
  final String? dailyDate;
  final int dailyScore;
  final int dailyStreak;

  const PublicProfile({
    required this.uid,
    required this.displayName,
    this.avatarId = 'detective',
    this.photoUrl,
    this.friendCode = '',
    this.totalStars = 0,
    this.highestLevel = 1,
    this.mpGames = 0,
    this.mpWins = 0,
    this.lastActive,
    this.status = PresenceStatus.offline,
    this.dailyDate,
    this.dailyScore = 0,
    this.dailyStreak = 0,
  });

  /// הניקוד באתגר של [dateKey], או null אם עוד לא שיחק/ה היום.
  int? dailyScoreOn(String dateKey) => dailyDate == dateKey ? dailyScore : null;

  /// הנוכחות האפקטיבית: גם אם המסמך אומר "online", אם הפעימה האחרונה ישנה
  /// מדי (האפליקציה נסגרה בלי להספיק לעדכן) - מציגים כלא מחובר/ת.
  PresenceStatus effectiveStatus([DateTime? now]) {
    final seen = lastActive;
    if (seen == null || status == PresenceStatus.offline) return PresenceStatus.offline;
    final age = (now ?? DateTime.now()).difference(seen);
    if (age > onlineWindow) return PresenceStatus.offline;
    return status;
  }

  bool isOnline([DateTime? now]) => effectiveStatus(now) != PresenceStatus.offline;

  /// טקסט נוכחות קצר בעברית ("מחובר/ת עכשיו", "במשחק", "נראה/תה לפני שעה").
  String presenceLabel([DateTime? now]) {
    switch (effectiveStatus(now)) {
      case PresenceStatus.online:
        return 'מחובר/ת עכשיו';
      case PresenceStatus.playing:
        return 'באמצע משחק';
      case PresenceStatus.offline:
        final seen = lastActive;
        if (seen == null) return 'לא מחובר/ת';
        return 'נראה/תה ${relativeTimeHe(seen, now)}';
    }
  }

  double get winRate => mpGames == 0 ? 0 : mpWins / mpGames;

  @override
  List<Object?> get props => [
        uid,
        displayName,
        avatarId,
        photoUrl,
        friendCode,
        totalStars,
        highestLevel,
        mpGames,
        mpWins,
        lastActive,
        status,
        dailyDate,
        dailyScore,
        dailyStreak,
      ];
}

/// "לפני X" בעברית, לתצוגת "נראה/תה לאחרונה".
String relativeTimeHe(DateTime time, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'ממש עכשיו';
  if (diff.inMinutes < 60) {
    return diff.inMinutes == 1 ? 'לפני דקה' : 'לפני ${diff.inMinutes} דקות';
  }
  if (diff.inHours < 24) {
    if (diff.inHours == 1) return 'לפני שעה';
    if (diff.inHours == 2) return 'לפני שעתיים';
    return 'לפני ${diff.inHours} שעות';
  }
  if (diff.inDays == 1) return 'אתמול';
  if (diff.inDays == 2) return 'לפני יומיים';
  if (diff.inDays < 7) return 'לפני ${diff.inDays} ימים';
  if (diff.inDays < 14) return 'לפני שבוע';
  return 'לפני ${(diff.inDays / 7).floor()} שבועות';
}

/// הרשומה שלי על חבר/ה אחד/ת (publicProfiles/{me}/friends/{uid}): ממתי
/// אנחנו חברים, ומאזן ניצחונות "ראש בראש" במשחקים משותפים.
class FriendRecord extends Equatable {
  final String uid;
  final DateTime? since;
  final int wins;
  final int losses;
  final int games;

  const FriendRecord({required this.uid, this.since, this.wins = 0, this.losses = 0, this.games = 0});

  int get draws => (games - wins - losses).clamp(0, games);

  @override
  List<Object?> get props => [uid, since, wins, losses, games];
}

/// חבר/ה לתצוגה: הכרטיס הציבורי + המאזן שלנו.
class FriendEntry extends Equatable {
  final PublicProfile profile;
  final FriendRecord record;

  const FriendEntry({required this.profile, required this.record});

  String get uid => profile.uid;

  @override
  List<Object?> get props => [profile, record];
}

class FriendRequest extends Equatable {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String fromAvatarId;
  final String? fromPhotoUrl;
  final String toName;
  final DateTime? createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    this.fromAvatarId = 'detective',
    this.fromPhotoUrl,
    this.toName = '',
    this.createdAt,
  });

  static String idFor(String fromUid, String toUid) => '${fromUid}_$toUid';

  @override
  List<Object?> get props => [id, fromUid, toUid, fromName, fromAvatarId, fromPhotoUrl, toName, createdAt];
}

enum InviteStatus { pending, accepted, declined, expired, cancelled }

/// הזמנה למשחק בחדר פרטי - נשלחת לחבר/ה ומוצגת אצלו/ה כחלון קופץ.
class GameInvite extends Equatable {
  /// כמה זמן ההזמנה בתוקף (כמו "Friendly Battle" ב-Clash Royale).
  static const lifetime = Duration(seconds: 60);

  final String id;
  final String fromUid;
  final String fromName;
  final String fromAvatarId;
  final String? fromPhotoUrl;
  final String toUid;
  final String toName;
  final String roomCode;
  final int gridSize;
  final int roundSeconds;
  final int entryFee;
  final DateTime? createdAt;
  final InviteStatus status;

  const GameInvite({
    required this.id,
    required this.fromUid,
    required this.fromName,
    this.fromAvatarId = 'detective',
    this.fromPhotoUrl,
    required this.toUid,
    this.toName = '',
    required this.roomCode,
    this.gridSize = 5,
    this.roundSeconds = 90,
    this.entryFee = 5,
    this.createdAt,
    this.status = InviteStatus.pending,
  });

  DateTime? get expiresAt => createdAt?.add(lifetime);

  bool isActive([DateTime? now]) {
    if (status != InviteStatus.pending) return false;
    final expiry = expiresAt;
    // createdAt עדיין null לרגע (חותמת שרת בדרך) - ההזמנה טרייה.
    if (expiry == null) return true;
    return (now ?? DateTime.now()).isBefore(expiry);
  }

  Duration remaining([DateTime? now]) {
    final expiry = expiresAt;
    if (expiry == null) return lifetime;
    final left = expiry.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  GameInvite copyWith({InviteStatus? status}) => GameInvite(
        id: id,
        fromUid: fromUid,
        fromName: fromName,
        fromAvatarId: fromAvatarId,
        fromPhotoUrl: fromPhotoUrl,
        toUid: toUid,
        toName: toName,
        roomCode: roomCode,
        gridSize: gridSize,
        roundSeconds: roundSeconds,
        entryFee: entryFee,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [
        id,
        fromUid,
        fromName,
        fromAvatarId,
        fromPhotoUrl,
        toUid,
        toName,
        roomCode,
        gridSize,
        roundSeconds,
        entryFee,
        createdAt,
        status,
      ];
}

/// שחקן/ית ששיחקנו איתו/ה לאחרונה בחדר פרטי - מוצע להוספה כחבר/ה.
class RecentPlayer extends Equatable {
  final String uid;
  final String displayName;
  final String avatarId;
  final DateTime playedAt;

  const RecentPlayer({
    required this.uid,
    required this.displayName,
    this.avatarId = 'detective',
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'avatarId': avatarId,
        'playedAt': playedAt.millisecondsSinceEpoch,
      };

  static RecentPlayer? fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    if (uid is! String || uid.isEmpty) return null;
    return RecentPlayer(
      uid: uid,
      displayName: json['displayName'] as String? ?? '?',
      avatarId: json['avatarId'] as String? ?? 'detective',
      playedAt: DateTime.fromMillisecondsSinceEpoch((json['playedAt'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  List<Object?> get props => [uid, displayName, avatarId, playedAt];
}
