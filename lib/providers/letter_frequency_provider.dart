import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// טוען את מפת תדירויות האותיות העברית (מחושבת מראש מתוך המילון) - משמשת
/// את [BoardGenerator] כדי להגריל לוחות עם התפלגות אותיות טבעית.
final letterFrequencyProvider = FutureProvider<Map<String, double>>((ref) async {
  final raw = await rootBundle.loadString('assets/config/letter_frequency.json');
  final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
});
