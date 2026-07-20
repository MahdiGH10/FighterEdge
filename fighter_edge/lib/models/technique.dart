class Technique {
  final String id;
  final String category; // Boxing, Kickboxing...
  final String discipline; // Striking, Wrestling, BJJ, Clinch
  final String title;
  final int videoCount;
  final String focus;

  const Technique({
    String? id,
    required this.category,
    required this.discipline,
    required this.title,
    required this.videoCount,
    this.focus = 'Drill slowly, then add resistance.',
  }) : id = id ?? '$discipline-$title';
}
