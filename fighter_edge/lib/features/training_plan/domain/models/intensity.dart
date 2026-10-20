/// How hard a session is. Ordered: [light] < [moderate] < [hard].
enum Intensity {
  light,
  moderate,
  hard;

  /// The lower of the two.
  Intensity capAt(Intensity cap) => index <= cap.index ? this : cap;
}
