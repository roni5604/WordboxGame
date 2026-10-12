/// דרגות הנדירות של כל המתנות וההפתעות במשחק - מהנפוצה לנדירה ביותר.
///
/// אותה סקאלה משמשת את תיבת המזל, כוכב המזל, הבונוס היומי וגלגל המזל, כך
/// שהשחקן/ית לומדים "שפה" אחת: אפור-כחלחל = רגיל, ירוק = לא שכיח, כחול =
/// נדיר, סגול = אפי, זהב = אגדי (ראו lib/core/ui/rarity_style.dart).
enum Rarity {
  common('רגיל'),
  uncommon('לא שכיח'),
  rare('נדיר'),
  epic('אפי'),
  legendary('אגדי');

  final String label;
  const Rarity(this.label);

  bool operator >=(Rarity other) => index >= other.index;
  bool operator >(Rarity other) => index > other.index;

  Rarity get next => this == Rarity.legendary ? this : Rarity.values[index + 1];
}
