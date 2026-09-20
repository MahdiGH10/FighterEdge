/// Coach-owned technique systems and paths shown in the Train library.
///
/// This is deliberately pure Dart and data-first: adding a future system (for
/// example, strength, conditioning, or a new martial art) means adding one
/// [TechniqueSystem] and its [TechniqueCategory] records. The UI does not need
/// a new switch branch or a redesigned navigation flow.
class TechniqueSystem {
  final String id;
  final String title;
  final String description;

  const TechniqueSystem({
    required this.id,
    required this.title,
    required this.description,
  });
}

/// A learnable path inside a [TechniqueSystem].
///
/// [techniques] is the coach's curriculum map, not a claim that every item has
/// a written drill or video already. Drill availability is derived separately
/// from the real [DrillCatalog], so the product stays honest as the curriculum
/// grows.
class TechniqueCategory {
  final String id;
  final String systemId;
  final String title;
  final String description;
  final List<String> techniques;

  const TechniqueCategory({
    required this.id,
    required this.systemId,
    required this.title,
    required this.description,
    required this.techniques,
  });
}

/// The first two technique systems supplied by the coaching team.
///
/// IDs are stable content keys. Do not use visible labels as identifiers:
/// labels can be localized or refined without breaking stored drill links.
class TechniqueTaxonomy {
  TechniqueTaxonomy._();

  static const strikingSystemId = 'striking';
  static const grapplingSystemId = 'grappling';

  static const systems = <TechniqueSystem>[
    TechniqueSystem(
      id: strikingSystemId,
      title: 'Striking',
      description: 'Range, offence, defence, and clinch exchanges.',
    ),
    TechniqueSystem(
      id: grapplingSystemId,
      title: 'Grappling',
      description: 'Entries, control, escapes, submissions, and stand-ups.',
    ),
  ];

  static const categories = <TechniqueCategory>[
    TechniqueCategory(
      id: 'striking.punches',
      systemId: strikingSystemId,
      title: 'Punches',
      description: 'Build clean, connected hands from stance and guard.',
      techniques: ['Jab', 'Cross', 'Lead hook', 'Uppercut'],
    ),
    TechniqueCategory(
      id: 'striking.kicks',
      systemId: strikingSystemId,
      title: 'Kicks',
      description: 'Control range and damage with balanced kicking mechanics.',
      techniques: ['Low kick', 'Body kick', 'High kick', 'Teep'],
    ),
    TechniqueCategory(
      id: 'striking.knees',
      systemId: strikingSystemId,
      title: 'Knees',
      description: 'Straight, curved, switching, and flying knee attacks.',
      techniques: [
        'Straight knee',
        'Curved body knee',
        'Switch knee',
        'Flying knee',
      ],
    ),
    TechniqueCategory(
      id: 'striking.elbows',
      systemId: strikingSystemId,
      title: 'Elbows',
      description: 'Short-range lines that work inside the pocket or clinch.',
      techniques: [
        'Horizontal elbow',
        'Upward elbow',
        'Diagonal elbow',
        'Spinning back elbow',
      ],
    ),
    TechniqueCategory(
      id: 'striking.punch_defense',
      systemId: strikingSystemId,
      title: 'Punch defense',
      description: 'Defend without losing posture, vision, or your return.',
      techniques: ['High guard', 'Parry', 'Slip', 'Pull'],
    ),
    TechniqueCategory(
      id: 'striking.kick_defense',
      systemId: strikingSystemId,
      title: 'Kick defense',
      description: 'Check, block, catch, and exit safely from kicking range.',
      techniques: [
        'Low-kick check',
        'Body-kick block',
        'Body-kick catch',
        'High-kick lean back',
      ],
    ),
    TechniqueCategory(
      id: 'striking.footwork',
      systemId: strikingSystemId,
      title: 'Footwork',
      description: 'Enter, exit, and create angles without crossing your feet.',
      techniques: [
        'Forward / back step',
        'Lateral movement',
        'Pivot',
        'Angle step',
      ],
    ),
    TechniqueCategory(
      id: 'striking.head_movement',
      systemId: strikingSystemId,
      title: 'Head movement',
      description: 'Make small defensive movements that keep you in range.',
      techniques: ['Slip', 'Roll', 'Pull', 'Duck'],
    ),
    TechniqueCategory(
      id: 'striking.counters',
      systemId: strikingSystemId,
      title: 'Counters',
      description: 'Turn a clean defensive read into the right return.',
      techniques: [
        'Jab to cross counter',
        'Slip to cross',
        'Check low kick',
        'Pull to cross',
      ],
    ),
    TechniqueCategory(
      id: 'striking.clinch_striking',
      systemId: strikingSystemId,
      title: 'Clinch striking',
      description: 'Control posture and strike with knees, elbows, and hands.',
      techniques: [
        'Collar tie to knee',
        'Double collar tie to knee',
        'Dirty boxing',
        'Clinch elbow',
      ],
    ),
    TechniqueCategory(
      id: 'striking.advanced_unorthodox',
      systemId: strikingSystemId,
      title: 'Advanced & unorthodox',
      description:
          'Higher-risk attacks to add after the fundamentals are sharp.',
      techniques: [
        'Spinning backfist',
        'Spinning kick',
        'Question-mark kick',
        'Axe kick',
      ],
    ),
    TechniqueCategory(
      id: 'striking.combinations',
      systemId: strikingSystemId,
      title: 'Combinations',
      description: 'Link tools together, then leave on balance.',
      techniques: [
        'Jab to cross',
        'Jab to cross to kick',
        'Jab to body kick',
        'Cross to hook to low kick',
      ],
    ),
    TechniqueCategory(
      id: 'grappling.takedowns',
      systemId: grapplingSystemId,
      title: 'Takedowns',
      description: 'Reliable entries to put an opponent on the mat.',
      techniques: ['Double leg', 'Single leg', 'Body lock', 'Ankle pick'],
    ),
    TechniqueCategory(
      id: 'grappling.takedown_defense',
      systemId: grapplingSystemId,
      title: 'Takedown defense',
      description: 'Deny the entry, recover position, and counter safely.',
      techniques: [
        'Double-leg defense',
        'Single-leg defense',
        'Whizzer',
        'Underhook',
      ],
    ),
    TechniqueCategory(
      id: 'grappling.ground_grappling',
      systemId: grapplingSystemId,
      title: 'Ground grappling',
      description:
          'Position, control, and escape from the major ground states.',
      techniques: ['Guard', 'Half guard', 'Side control', 'Mount'],
    ),
    TechniqueCategory(
      id: 'grappling.clinch_grappling',
      systemId: grapplingSystemId,
      title: 'Clinch grappling',
      description: 'Win inside position before you wrestle or strike.',
      techniques: ['Pummeling', 'Underhook', 'Body lock', 'Collar tie'],
    ),
    TechniqueCategory(
      id: 'grappling.judo_throws',
      systemId: grapplingSystemId,
      title: 'Judo & throws',
      description: 'Off-balance, turn, and finish controlled throwing entries.',
      techniques: ['Osoto gari', 'Ouchi gari', 'Harai goshi', 'Kosoto gake'],
    ),
    TechniqueCategory(
      id: 'grappling.sprawling',
      systemId: grapplingSystemId,
      title: 'Sprawling',
      description: 'Stop shots, take the head, and recover to a safe position.',
      techniques: [
        'Basic sprawl',
        'Front headlock',
        'Back take',
        'Disengage',
      ],
    ),
    TechniqueCategory(
      id: 'grappling.submissions',
      systemId: grapplingSystemId,
      title: 'Submissions',
      description: 'Fundamental high-percentage finishes and their control.',
      techniques: ['Rear naked choke', 'Guillotine', 'Armbar', 'Triangle'],
    ),
    TechniqueCategory(
      id: 'grappling.submission_defense',
      systemId: grapplingSystemId,
      title: 'Submission defense',
      description: 'Recognize danger early and escape with structure.',
      techniques: [
        'Rear naked choke defense',
        'Guillotine defense',
        'Armbar defense',
        'Triangle defense',
      ],
    ),
    TechniqueCategory(
      id: 'grappling.mma_ground_fighting',
      systemId: grapplingSystemId,
      title: 'MMA ground fighting',
      description: 'Build decisions for the cage, strikes, and safe stand-ups.',
      techniques: [
        'Ground-and-pound guard',
        'Ground-and-pound half guard',
        'Wall walk',
        'Technical stand-up',
      ],
    ),
    TechniqueCategory(
      id: 'grappling.fundamentals',
      systemId: grapplingSystemId,
      title: 'Fundamentals',
      description: 'The movements that make every grappling position work.',
      techniques: ['Shrimp', 'Bridge', 'Frames', 'Hip heist'],
    ),
  ];

  static final Map<String, TechniqueSystem> _systemsById = {
    for (final system in systems) system.id: system,
  };
  static final Map<String, TechniqueCategory> _categoriesById = {
    for (final category in categories) category.id: category,
  };
  static final Map<String, List<TechniqueCategory>> _categoriesBySystem =
      Map<String, List<TechniqueCategory>>.unmodifiable({
    for (final system in systems)
      system.id: List<TechniqueCategory>.unmodifiable(
        categories.where((category) => category.systemId == system.id),
      ),
  });

  static TechniqueSystem? systemById(String id) => _systemsById[id];

  static TechniqueCategory? categoryById(String id) => _categoriesById[id];

  static List<TechniqueCategory> categoriesForSystem(String systemId) =>
      _categoriesBySystem[systemId] ?? const <TechniqueCategory>[];
}
