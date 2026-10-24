import 'package:flutter/material.dart';

import 'character_painter.dart';

/// קטגוריות בבורר הדמויות.
enum AvatarCategory { classic, kids, characters, dogs, animals }

extension AvatarCategoryX on AvatarCategory {
  String get labelHe => switch (this) {
    AvatarCategory.classic => 'קלאסי',
    AvatarCategory.kids => 'ילדים',
    AvatarCategory.characters => 'דמויות',
    AvatarCategory.dogs => 'כלבים',
    AvatarCategory.animals => 'חיות',
  };

  IconData get icon => switch (this) {
    AvatarCategory.classic => Icons.star_rounded,
    AvatarCategory.kids => Icons.face_rounded,
    AvatarCategory.characters => Icons.theater_comedy_rounded,
    AvatarCategory.dogs => Icons.pets_rounded,
    AvatarCategory.animals => Icons.cruelty_free_rounded,
  };
}

/// דמות מצוירת בקוד. [id] נשמר בפרופיל (עד 40 תווים, ראו firestore.rules).
class PaintedAvatar {
  final String id;
  final String label;
  final AvatarCategory category;
  final HumanLook? human;
  final AnimalLook? animal;

  const PaintedAvatar.human(this.id, this.label, this.category, HumanLook look) : human = look, animal = null;

  const PaintedAvatar.animal(this.id, this.label, this.category, AnimalLook look) : animal = look, human = null;

  CharacterPainter get painter => human != null ? CharacterPainter.human(human!) : CharacterPainter.animal(animal!);
}

// צבעי שיער.
const _black = Color(0xFF2B2121);
const _brown = Color(0xFF6B3E26);
const _chestnut = Color(0xFF8E4B2A);
const _blond = Color(0xFFF2C14E);
const _ginger = Color(0xFFD9622B);
const _white = Color(0xFFF5F5F5);
const _pink = Color(0xFFFF8FC0);
const _blue = Color(0xFF64B5F6);

/// כל הדמויות המצוירות (בנוסף לשתיים הקלאסיות שמגיעות מתמונות).
const List<PaintedAvatar> kPaintedAvatars = [
  // ------------------------------------------------ ילדים וילדות
  PaintedAvatar.human(
    'kid_b1',
    'נועם',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.short,
      hairColor: _blond,
      outfit: Color(0xFF42A5F5),
      background: Color(0xFFBBDEFB),
    ),
  ),
  PaintedAvatar.human(
    'kid_g1',
    'מיה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.pigtails,
      hairColor: _ginger,
      lashes: true,
      freckles: true,
      outfit: Color(0xFFFF7AA8),
      background: Color(0xFFFFD6E7),
    ),
  ),
  PaintedAvatar.human(
    'kid_b2',
    'אריאל',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.spiky,
      hairColor: _brown,
      outfit: Color(0xFF66BB6A),
      background: Color(0xFFC8F2C9),
    ),
  ),
  PaintedAvatar.human(
    'kid_g2',
    'תמר',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.long,
      hairColor: _chestnut,
      lashes: true,
      accessory: Accessory.bow,
      outfit: Color(0xFFAB47BC),
      background: Color(0xFFEBD3F5),
    ),
  ),
  PaintedAvatar.human(
    'kid_b3',
    'יונתן',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.tan,
      hair: HairStyle.curly,
      hairColor: _black,
      accessory: Accessory.kippah,
      outfit: Color(0xFF26A69A),
      background: Color(0xFFB2EBE4),
    ),
  ),
  PaintedAvatar.human(
    'kid_g3',
    'ליה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.tan,
      hair: HairStyle.ponytail,
      hairColor: _brown,
      lashes: true,
      outfit: Color(0xFFFFA726),
      background: Color(0xFFFFE0B2),
    ),
  ),
  PaintedAvatar.human(
    'kid_b4',
    'עומר',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.olive,
      hair: HairStyle.short,
      hairColor: _black,
      accessory: Accessory.cap,
      outfit: Color(0xFFEF5350),
      background: Color(0xFFFFCDD2),
    ),
  ),
  PaintedAvatar.human(
    'kid_g4',
    'נועה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.olive,
      hair: HairStyle.braids,
      hairColor: _black,
      lashes: true,
      outfit: Color(0xFF5C6BC0),
      background: Color(0xFFD1D9FF),
    ),
  ),
  PaintedAvatar.human(
    'kid_b5',
    'איתי',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.brown,
      hair: HairStyle.afro,
      hairColor: _black,
      outfit: Color(0xFFFFCA28),
      background: Color(0xFFFFF3C4),
    ),
  ),
  PaintedAvatar.human(
    'kid_g5',
    'שירה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.brown,
      hair: HairStyle.afro,
      hairColor: _black,
      lashes: true,
      accessory: Accessory.flower,
      outfit: Color(0xFFEC407A),
      background: Color(0xFFFFD1E3),
    ),
  ),
  PaintedAvatar.human(
    'kid_b6',
    'דניאל',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.deep,
      hair: HairStyle.buzz,
      hairColor: _black,
      accessory: Accessory.headphones,
      outfit: Color(0xFF7E57C2),
      background: Color(0xFFDCD0FF),
    ),
  ),
  PaintedAvatar.human(
    'kid_g6',
    'אביגיל',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.deep,
      hair: HairStyle.braids,
      hairColor: _black,
      lashes: true,
      accessory: Accessory.bow,
      outfit: Color(0xFF29B6F6),
      background: Color(0xFFC6EBFF),
    ),
  ),
  PaintedAvatar.human(
    'kid_b7',
    'קנג׳י',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.bob,
      hairColor: _black,
      accessory: Accessory.glasses,
      outfit: Color(0xFF8D6E63),
      background: Color(0xFFEAD9CF),
    ),
  ),
  PaintedAvatar.human(
    'kid_g7',
    'מיי',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.bun,
      hairColor: _black,
      lashes: true,
      outfit: Color(0xFFFF8A65),
      background: Color(0xFFFFDDD2),
    ),
  ),
  PaintedAvatar.human(
    'kid_b8',
    'רפאל',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.mohawk,
      hairColor: _ginger,
      freckles: true,
      outfit: Color(0xFF9CCC65),
      background: Color(0xFFE1F5C4),
    ),
  ),
  PaintedAvatar.human(
    'kid_g8',
    'יסמין',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.tan,
      hair: HairStyle.hijab,
      hairColor: Color(0xFF26A69A),
      lashes: true,
      outfit: Color(0xFF26A69A),
      background: Color(0xFFC9F1EC),
    ),
  ),
  PaintedAvatar.human(
    'kid_b9',
    'אליה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.brown,
      hair: HairStyle.curly,
      hairColor: _brown,
      accessory: Accessory.glasses,
      outfit: Color(0xFF42A5F5),
      background: Color(0xFFD6ECFF),
    ),
  ),
  PaintedAvatar.human(
    'kid_g9',
    'אלה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.wavy,
      hairColor: _blond,
      lashes: true,
      outfit: Color(0xFF7E57C2),
      background: Color(0xFFE6DCFF),
    ),
  ),
  PaintedAvatar.human(
    'kid_b10',
    'סבא חכם',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.buzz,
      hairColor: _white,
      accessory: Accessory.glasses,
      outfit: Color(0xFF78909C),
      background: Color(0xFFDDE5EA),
    ),
  ),
  PaintedAvatar.human(
    'kid_g10',
    'סבתא חכמה',
    AvatarCategory.kids,
    HumanLook(
      skin: SkinTones.olive,
      hair: HairStyle.bun,
      hairColor: _white,
      lashes: true,
      accessory: Accessory.glasses,
      outfit: Color(0xFFBA68C8),
      background: Color(0xFFF1DDF7),
    ),
  ),

  // ------------------------------------------------ דמויות קומיות
  PaintedAvatar.human(
    'ch_king',
    'מלך',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.short,
      hairColor: _brown,
      accessory: Accessory.crown,
      outfit: Color(0xFFC62828),
      background: Color(0xFFFFE08A),
    ),
  ),
  PaintedAvatar.human(
    'ch_queen',
    'מלכה',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.brown,
      hair: HairStyle.long,
      hairColor: _black,
      lashes: true,
      accessory: Accessory.crown,
      outfit: Color(0xFF6A1B9A),
      background: Color(0xFFFFE08A),
    ),
  ),
  PaintedAvatar.human(
    'ch_prince',
    'נסיך',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.tan,
      hair: HairStyle.curly,
      hairColor: _black,
      accessory: Accessory.tiara,
      outfit: Color(0xFF1565C0),
      background: Color(0xFFCDE6FF),
    ),
  ),
  PaintedAvatar.human(
    'ch_princess',
    'נסיכה',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.wavy,
      hairColor: _blond,
      lashes: true,
      accessory: Accessory.tiara,
      outfit: Color(0xFFF06292),
      background: Color(0xFFFFD6EA),
    ),
  ),
  PaintedAvatar.human(
    'ch_clown_b',
    'ליצן',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.none,
      hairColor: _white,
      accessory: Accessory.clown,
      outfit: Color(0xFFFFCA28),
      background: Color(0xFFB9F6CA),
    ),
  ),
  PaintedAvatar.human(
    'ch_clown_g',
    'ליצנית',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.brown,
      hair: HairStyle.none,
      hairColor: _white,
      lashes: true,
      accessory: Accessory.clown,
      outfit: Color(0xFFFF7AA8),
      background: Color(0xFFFFF59D),
    ),
  ),
  PaintedAvatar.human(
    'ch_angel_b',
    'מלאך',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.curly,
      hairColor: _blond,
      accessory: Accessory.halo,
      outfit: Color(0xFFE3F2FD),
      background: Color(0xFFB3E5FC),
    ),
  ),
  PaintedAvatar.human(
    'ch_angel_g',
    'מלאכית',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.deep,
      hair: HairStyle.long,
      hairColor: _black,
      lashes: true,
      accessory: Accessory.halo,
      outfit: Color(0xFFFFFDE7),
      background: Color(0xFFB3E5FC),
    ),
  ),
  PaintedAvatar.human(
    'ch_devil_b',
    'שטן קטן',
    AvatarCategory.characters,
    HumanLook(
      skin: Color(0xFFFF8A80),
      hair: HairStyle.spiky,
      hairColor: _black,
      accessory: Accessory.horns,
      outfit: Color(0xFF212121),
      background: Color(0xFFFF5252),
    ),
  ),
  PaintedAvatar.human(
    'ch_devil_g',
    'שטנית קטנה',
    AvatarCategory.characters,
    HumanLook(
      skin: Color(0xFFFF8A80),
      hair: HairStyle.bob,
      hairColor: _black,
      lashes: true,
      accessory: Accessory.horns,
      outfit: Color(0xFF212121),
      background: Color(0xFFFF5252),
    ),
  ),
  PaintedAvatar.human(
    'ch_pirate_b',
    'פיראט',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.olive,
      hair: HairStyle.long,
      hairColor: _brown,
      accessory: Accessory.pirate,
      outfit: Color(0xFFD32F2F),
      background: Color(0xFF80DEEA),
    ),
  ),
  PaintedAvatar.human(
    'ch_pirate_g',
    'פיראטית',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.long,
      hairColor: _ginger,
      lashes: true,
      accessory: Accessory.pirate,
      outfit: Color(0xFF283593),
      background: Color(0xFF80DEEA),
    ),
  ),
  PaintedAvatar.human(
    'ch_wizard',
    'קוסם',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.long,
      hairColor: _white,
      accessory: Accessory.wizardHat,
      outfit: Color(0xFF3949AB),
      background: Color(0xFFC5CAE9),
    ),
  ),
  PaintedAvatar.human(
    'ch_witch',
    'מכשפה טובה',
    AvatarCategory.characters,
    HumanLook(
      skin: Color(0xFFB9F6CA),
      hair: HairStyle.long,
      hairColor: Color(0xFF7B1FA2),
      lashes: true,
      accessory: Accessory.witchHat,
      outfit: Color(0xFF6A1B9A),
      background: Color(0xFFE1BEE7),
    ),
  ),
  PaintedAvatar.human(
    'ch_chef',
    'שף',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.tan,
      hair: HairStyle.short,
      hairColor: _black,
      accessory: Accessory.chefHat,
      outfit: Color(0xFFF5F5F5),
      background: Color(0xFFFFCC80),
    ),
  ),
  PaintedAvatar.human(
    'ch_ninja',
    'נינג׳ה',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.none,
      hairColor: _black,
      accessory: Accessory.ninja,
      outfit: Color(0xFF263238),
      background: Color(0xFFB0BEC5),
    ),
  ),
  PaintedAvatar.human(
    'ch_astro_b',
    'אסטרונאוט',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.brown,
      hair: HairStyle.buzz,
      hairColor: _black,
      accessory: Accessory.astronaut,
      background: Color(0xFF283593),
    ),
  ),
  PaintedAvatar.human(
    'ch_astro_g',
    'אסטרונאוטית',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.light,
      hair: HairStyle.bob,
      hairColor: _chestnut,
      lashes: true,
      accessory: Accessory.astronaut,
      background: Color(0xFF4527A0),
    ),
  ),
  PaintedAvatar.human(
    'ch_hero_b',
    'גיבור על',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.olive,
      hair: HairStyle.spiky,
      hairColor: _black,
      accessory: Accessory.hero,
      outfit: Color(0xFF1E88E5),
      background: Color(0xFFFFE082),
    ),
  ),
  PaintedAvatar.human(
    'ch_hero_g',
    'גיבורת על',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.deep,
      hair: HairStyle.ponytail,
      hairColor: _black,
      lashes: true,
      accessory: Accessory.hero,
      outfit: Color(0xFFE53935),
      background: Color(0xFFFFE082),
    ),
  ),
  PaintedAvatar.human(
    'ch_vampire',
    'ערפד חמוד',
    AvatarCategory.characters,
    HumanLook(
      skin: Color(0xFFE8EAF6),
      hair: HairStyle.short,
      hairColor: _black,
      accessory: Accessory.vampire,
      outfit: Color(0xFF212121),
      background: Color(0xFF7E57C2),
    ),
  ),
  PaintedAvatar.human(
    'ch_rock',
    'כוכב רוק',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.fair,
      hair: HairStyle.mohawk,
      hairColor: _pink,
      accessory: Accessory.headphones,
      outfit: Color(0xFF212121),
      background: Color(0xFFFF80AB),
    ),
  ),
  PaintedAvatar.human(
    'ch_mermaid',
    'בת ים',
    AvatarCategory.characters,
    HumanLook(
      skin: SkinTones.tan,
      hair: HairStyle.wavy,
      hairColor: _blue,
      lashes: true,
      accessory: Accessory.flower,
      outfit: Color(0xFF26C6DA),
      background: Color(0xFF84FFFF),
    ),
  ),
  PaintedAvatar.animal(
    'ch_robot',
    'רובוט',
    AvatarCategory.characters,
    AnimalLook(
      kind: AnimalKind.robot,
      fur: Color(0xFFB0BEC5),
      accent: Color(0xFF64FFDA),
      background: Color(0xFF80CBC4),
    ),
  ),
  PaintedAvatar.animal(
    'ch_alien',
    'חייזר',
    AvatarCategory.characters,
    AnimalLook(
      kind: AnimalKind.alien,
      fur: Color(0xFF9CE37D),
      accent: Color(0xFFFFEB3B),
      background: Color(0xFF311B92),
    ),
  ),

  // ------------------------------------------------ כלבים
  PaintedAvatar.animal(
    'dog_pointer',
    'פוינטר בלש',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.pointer,
      fur: Color(0xFF6D4C41),
      accent: Color(0xFF5D4037),
      background: Color(0xFFFFE0B2),
    ),
  ),
  PaintedAvatar.animal(
    'dog_boxer',
    'בוקסר',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.boxer,
      fur: Color(0xFFC77D3A),
      accent: Color(0xFFFFF3E0),
      background: Color(0xFFFFCCBC),
    ),
  ),
  PaintedAvatar.animal(
    'dog_chihuahua',
    'צ׳יוואווה',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.chihuahua,
      fur: Color(0xFFE9B97A),
      accent: Color(0xFFFFF3E0),
      background: Color(0xFFFFF59D),
    ),
  ),
  PaintedAvatar.animal(
    'dog_husky',
    'האסקי',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.husky,
      fur: Color(0xFF78909C),
      accent: Color(0xFFFAFAFA),
      background: Color(0xFFB3E5FC),
    ),
  ),
  PaintedAvatar.animal(
    'dog_dalmatian',
    'דלמטי',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.dalmatian,
      fur: Color(0xFFFAFAFA),
      accent: Color(0xFF263238),
      background: Color(0xFFFFCDD2),
    ),
  ),
  PaintedAvatar.animal(
    'dog_poodle',
    'פודל',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.poodle,
      fur: Color(0xFFF8BBD0),
      accent: Color(0xFFFCE4EC),
      background: Color(0xFFE1BEE7),
    ),
  ),
  PaintedAvatar.animal(
    'dog_pug',
    'פאג',
    AvatarCategory.dogs,
    AnimalLook(kind: AnimalKind.pug, fur: Color(0xFFE6C9A0), accent: Color(0xFF4E342E), background: Color(0xFFC5E1A5)),
  ),
  PaintedAvatar.animal(
    'dog_golden',
    'גולדן רטריבר',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.golden,
      fur: Color(0xFFE0A84F),
      accent: Color(0xFFFFE0B2),
      background: Color(0xFFB2DFDB),
    ),
  ),
  PaintedAvatar.animal(
    'dog_beagle',
    'ביגל',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.beagle,
      fur: Color(0xFFB9763C),
      accent: Color(0xFFFAFAFA),
      background: Color(0xFFD1C4E9),
    ),
  ),
  PaintedAvatar.animal(
    'dog_shiba',
    'שיבה אינו',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.shiba,
      fur: Color(0xFFE38B3A),
      accent: Color(0xFFFFF8E1),
      background: Color(0xFFFFE082),
    ),
  ),
  PaintedAvatar.animal(
    'dog_corgi',
    'קורגי',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.corgi,
      fur: Color(0xFFE59A4B),
      accent: Color(0xFFFFFFFF),
      background: Color(0xFFB3E5FC),
    ),
  ),
  PaintedAvatar.animal(
    'dog_dachshund',
    'תחש',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.dachshund,
      fur: Color(0xFF8D4F2A),
      accent: Color(0xFFC88A5C),
      background: Color(0xFFFFCCBC),
    ),
  ),
  PaintedAvatar.animal(
    'dog_labrador',
    'לברדור שחור',
    AvatarCategory.dogs,
    AnimalLook(
      kind: AnimalKind.labrador,
      fur: Color(0xFF37352F),
      accent: Color(0xFF5D5A52),
      background: Color(0xFFFFD54F),
    ),
  ),

  // ------------------------------------------------ חיות
  PaintedAvatar.animal(
    'an_cat_orange',
    'חתול ג׳ינג׳י',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.cat, fur: Color(0xFFF39C4A), accent: Color(0xFFFFE0B2), background: Color(0xFFC8E6C9)),
  ),
  PaintedAvatar.animal(
    'an_cat_gray',
    'חתולה אפורה',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.cat, fur: Color(0xFF9E9E9E), accent: Color(0xFFEEEEEE), background: Color(0xFFF8BBD0)),
  ),
  PaintedAvatar.animal(
    'an_cat_black',
    'חתול שחור',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.cat, fur: Color(0xFF2E2B33), accent: Color(0xFF4A4650), background: Color(0xFFFFE082)),
  ),
  PaintedAvatar.animal(
    'an_bunny',
    'ארנבת',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.bunny,
      fur: Color(0xFFF5F5F5),
      accent: Color(0xFFFFCDD2),
      background: Color(0xFFB2EBF2),
    ),
  ),
  PaintedAvatar.animal(
    'an_bear',
    'דובי',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.bear, fur: Color(0xFF8D5A3B), accent: Color(0xFFD7B08C), background: Color(0xFFDCEDC8)),
  ),
  PaintedAvatar.animal(
    'an_panda',
    'פנדה',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.panda,
      fur: Color(0xFFFAFAFA),
      accent: Color(0xFF263238),
      background: Color(0xFFA5D6A7),
    ),
  ),
  PaintedAvatar.animal(
    'an_fox',
    'שועל',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.fox, fur: Color(0xFFF57C2A), accent: Color(0xFFFFFFFF), background: Color(0xFFB3E5FC)),
  ),
  PaintedAvatar.animal(
    'an_lion',
    'אריה',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.lion, fur: Color(0xFFF2B84B), accent: Color(0xFFC1662B), background: Color(0xFFFFF59D)),
  ),
  PaintedAvatar.animal(
    'an_tiger',
    'נמר',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.tiger,
      fur: Color(0xFFF59331),
      accent: Color(0xFF3E2723),
      background: Color(0xFFC8E6C9),
    ),
  ),
  PaintedAvatar.animal(
    'an_frog',
    'צפרדע',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.frog, fur: Color(0xFF7CCB5A), accent: Color(0xFFC5E1A5), background: Color(0xFFB2EBF2)),
  ),
  PaintedAvatar.animal(
    'an_owl',
    'ינשוף',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.owl, fur: Color(0xFF8D6E63), accent: Color(0xFFD7CCC8), background: Color(0xFF9FA8DA)),
  ),
  PaintedAvatar.animal(
    'an_penguin',
    'פינגווין',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.penguin,
      fur: Color(0xFF37474F),
      accent: Color(0xFFFAFAFA),
      background: Color(0xFFB3E5FC),
    ),
  ),
  PaintedAvatar.animal(
    'an_unicorn',
    'חד-קרן',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.unicorn,
      fur: Color(0xFFFFFFFF),
      accent: Color(0xFFFFCDD2),
      background: Color(0xFFE1BEE7),
    ),
  ),
  PaintedAvatar.animal(
    'an_monkey',
    'קוף',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.monkey,
      fur: Color(0xFF8D6E63),
      accent: Color(0xFFFFE0B2),
      background: Color(0xFFFFF59D),
    ),
  ),
  PaintedAvatar.animal(
    'an_koala',
    'קואלה',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.koala,
      fur: Color(0xFF9EA7AD),
      accent: Color(0xFFE0E0E0),
      background: Color(0xFFC5E1A5),
    ),
  ),
  PaintedAvatar.animal(
    'an_pig',
    'חזרזירה',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.pig, fur: Color(0xFFFFA8B8), accent: Color(0xFFFFCDD2), background: Color(0xFFB2DFDB)),
  ),
  PaintedAvatar.animal(
    'an_cow',
    'פרה',
    AvatarCategory.animals,
    AnimalLook(kind: AnimalKind.cow, fur: Color(0xFFFAFAFA), accent: Color(0xFFFFCCBC), background: Color(0xFFC8E6C9)),
  ),
  PaintedAvatar.animal(
    'an_mouse',
    'עכבר',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.mouse,
      fur: Color(0xFFBDBDBD),
      accent: Color(0xFFF5F5F5),
      background: Color(0xFFFFE0B2),
    ),
  ),
  PaintedAvatar.animal(
    'an_elephant',
    'פיל',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.elephant,
      fur: Color(0xFF90A4AE),
      accent: Color(0xFFCFD8DC),
      background: Color(0xFFFFCCBC),
    ),
  ),
  PaintedAvatar.animal(
    'an_chick',
    'אפרוח',
    AvatarCategory.animals,
    AnimalLook(
      kind: AnimalKind.chick,
      fur: Color(0xFFFFE066),
      accent: Color(0xFFFFA726),
      background: Color(0xFF90CAF9),
    ),
  ),
];

PaintedAvatar? paintedAvatarFor(String id) {
  for (final a in kPaintedAvatars) {
    if (a.id == id) return a;
  }
  return null;
}

/// דמות ייחודית לכל בוט, לפי שמו (ואם השם לא ברשימה - לפי hash יציב).
const _botAvatarByName = {
  'עומר': 'kid_b4',
  'נועה': 'kid_g4',
  'דנה': 'kid_g9',
  'יובל': 'kid_b7',
  'טל': 'dog_shiba',
  'מאיה': 'an_cat_gray',
  'איתי': 'kid_b5',
  'שירה': 'kid_g5',
};

String botAvatarId(String botName) {
  final known = _botAvatarByName[botName];
  if (known != null) return known;
  final hash = botName.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
  return kPaintedAvatars[hash % kPaintedAvatars.length].id;
}
