class WeightEntry {
  final String id;
  final DateTime date;
  final double kg;
  const WeightEntry(this.date, this.kg, {String? id}) : id = id ?? '';

  String get stableId =>
      id.isNotEmpty ? id : date.millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'kg': kg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    return WeightEntry(
      DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      (json['kg'] as num?)?.toDouble() ?? 0,
      id: id,
    );
  }
}
