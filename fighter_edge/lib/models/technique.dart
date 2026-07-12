class Technique {
  final String category; // Boxing, Kickboxing...
  final String discipline; // Striking, Wrestling, BJJ, Clinch
  final String title;
  final int videoCount;

  const Technique({
    required this.category,
    required this.discipline,
    required this.title,
    required this.videoCount,
  });
}
