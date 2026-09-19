import 'drill.dart';

/// The bundled drill library.
///
/// Written coaching, not video: every entry is complete on its own — what
/// the technique is for, the points that make it work, the mistakes that
/// break it, and a concrete way to put reps on it. One starter drill per
/// discipline is free so a free account gets a real taste of each.
class DrillCatalog {
  DrillCatalog._();

  static const all = <Drill>[
    // ── Striking ──────────────────────────────────────────────────────────
    Drill(
      id: 'jab',
      discipline: DrillDiscipline.striking,
      sport: 'BOXING',
      title: 'The Jab',
      summary: 'Your range finder and the setup for almost everything else.',
      level: DrillLevel.fundamentals,
      starter: true,
      keyPoints: [
        'Turn the lead fist over at the end so the knuckles land flat.',
        'Step with the jab when you need range; the front foot lands with '
            'the punch, not after it.',
        'Rear hand stays glued to the chin the whole time.',
        'Snap it back along the same line it went out.',
      ],
      commonMistakes: [
        'Dropping the jab hand on the way back — the classic opening for '
            'the counter right.',
        'Leaning the head past the front knee to reach.',
      ],
      prescription: '3 rounds × 2 min shadowboxing, jab only: singles, '
          'doubles, and a jab while stepping back. 1 min rest.',
    ),
    Drill(
      id: 'one_two',
      discipline: DrillDiscipline.striking,
      sport: 'BOXING',
      title: 'The 1-2',
      summary: 'Jab, then cross — the combination every other one is built '
          'on.',
      level: DrillLevel.fundamentals,
      keyPoints: [
        'The cross starts from the rear foot: pivot the heel out and turn '
            'the hip through.',
        'Throw the cross down the centre line, straight from the chin.',
        'The jab hand returns to the face as the cross goes out.',
        'Finish balanced, weight centred, ready to throw again or move.',
      ],
      commonMistakes: [
        'Winding up — pulling the rear hand back before throwing it.',
        'Falling forward onto the front foot after the cross.',
      ],
      prescription: '4 rounds × 2 min on the bag: 1-2, reset feet, repeat. '
          'Last 30 s of each round as fast as you can while staying tight.',
    ),
    Drill(
      id: 'lead_hook',
      discipline: DrillDiscipline.striking,
      sport: 'BOXING',
      title: 'Lead Hook',
      summary: 'The short power shot that lands when the opponent is '
          'watching the straight punches.',
      level: DrillLevel.intermediate,
      keyPoints: [
        'Power comes from pivoting the lead foot and turning the hips, not '
            'swinging the arm.',
        'Elbow at shoulder height, arm bent near 90°, thumb up or palm '
            'down — pick one and stay consistent.',
        'Keep it short: the hook lands inside, at close range.',
      ],
      commonMistakes: [
        'Looping it wide, which telegraphs it and opens your chin.',
        'Leaving the rear hand low while the lead hand is committed.',
      ],
      prescription: '3 rounds × 2 min on the bag: 1-2-3 (jab, cross, lead '
          'hook). Focus on the pivot, not the speed.',
    ),
    Drill(
      id: 'slip_counter',
      discipline: DrillDiscipline.striking,
      sport: 'BOXING',
      title: 'Slip & Counter',
      summary: 'Make them miss, then make them pay — defence that creates '
          'offence.',
      level: DrillLevel.intermediate,
      needsPartner: true,
      keyPoints: [
        'Slip by bending at the knees and rotating the shoulders a few '
            'inches off the line — not by bending at the waist.',
        'Eyes stay on the opponent through the slip.',
        'Counter immediately while their hand is still extended.',
      ],
      commonMistakes: [
        'Slipping too far, which takes you out of range to counter.',
        'Slipping before the punch comes — reacting to shoulders, not '
            'guessing.',
      ],
      prescription: 'Partner throws slow jabs for 3 × 2 min rounds: slip '
          'outside, counter with a cross. Increase speed only when the slip '
          'is clean.',
    ),
    Drill(
      id: 'teep',
      discipline: DrillDiscipline.striking,
      sport: 'MUAY THAI',
      title: 'The Teep',
      summary: 'A push kick that controls distance and breaks the '
          "opponent's rhythm.",
      level: DrillLevel.fundamentals,
      keyPoints: [
        'Lift the knee high first, then extend the hips into the target.',
        'Land with the ball of the foot on the stomach or hip.',
        'Lean back slightly for balance; hands stay up.',
        'Retract quickly and land back in stance.',
      ],
      commonMistakes: [
        'Pushing with the leg only — no hip extension means no power.',
        'Dropping the hands to balance.',
      ],
      prescription: '3 rounds × 2 min on the bag: 10 lead teeps, 10 rear '
          'teeps, repeat. Reset stance after every kick.',
    ),
    Drill(
      id: 'round_kick',
      discipline: DrillDiscipline.striking,
      sport: 'MUAY THAI',
      title: 'Body Round Kick',
      summary: 'The heavy kick to the body that drains an opponent round by '
          'round.',
      level: DrillLevel.intermediate,
      keyPoints: [
        'Step out at an angle with the lead foot to open the hips.',
        'Pivot fully on the ball of the standing foot so the heel points '
            'at the target.',
        'Swing the leg through as one unit and strike with the shin.',
        'The same-side arm swings down for balance; the other hand guards '
            'the face.',
      ],
      commonMistakes: [
        'Not pivoting the standing foot, which stalls the hip and strains '
            'the knee.',
        'Kicking with the foot or instep instead of the shin.',
      ],
      prescription: '4 rounds × 2 min on the bag, alternating sides every '
          '10 kicks. Quality over pace until the pivot is automatic.',
    ),
    Drill(
      id: 'low_kick_check',
      discipline: DrillDiscipline.striking,
      sport: 'KICKBOXING',
      title: 'Low Kick & Check',
      summary: 'Throw the calf and thigh kick safely, and stop it coming back '
          'at you.',
      level: DrillLevel.intermediate,
      needsPartner: true,
      keyPoints: [
        'Set the low kick up with punches so the eyes go high.',
        'Turn the hip over and cut down through the thigh with the shin.',
        'To check: lift the knee and turn the shin out to meet the kick — '
            'shin to shin.',
        'Keep your hands up while checking; the kick is often followed by '
            'a punch.',
      ],
      commonMistakes: [
        'Throwing it naked, with no setup, into a waiting check.',
        'Checking late with the leg turned in, which takes the kick on the '
            'calf.',
      ],
      prescription: 'Partner drill, 3 × 2 min: one feeds light low kicks, '
          'the other checks and returns a 1-2. Switch roles each round.',
    ),
    Drill(
      id: 'pivot_angle',
      discipline: DrillDiscipline.striking,
      sport: 'FOOTWORK',
      title: 'Pivot & Angle Out',
      summary: 'Get off the centre line after you punch, instead of standing '
          'in front of the return fire.',
      level: DrillLevel.fundamentals,
      keyPoints: [
        'Pivot on the ball of the lead foot and swing the rear foot around.',
        'Keep your stance width through the turn.',
        'Pivot after throwing, while their guard is still reacting.',
      ],
      commonMistakes: [
        'Crossing the feet, which leaves you off balance mid-turn.',
        'Pivoting without punching first — turning in front of a fresh '
            'opponent.',
      ],
      prescription: '3 rounds × 2 min shadowboxing: 1-2, pivot left; 1-2, '
          'step out right. Keep moving the whole round.',
    ),

    // ── Wrestling ─────────────────────────────────────────────────────────
    Drill(
      id: 'stance_level_change',
      discipline: DrillDiscipline.wrestling,
      sport: 'WRESTLING',
      title: 'Stance & Level Change',
      summary: 'Every takedown starts here: dropping your hips without '
          'dropping your head.',
      level: DrillLevel.fundamentals,
      starter: true,
      keyPoints: [
        'Staggered stance, knees bent, hips low, elbows in.',
        'Change levels by bending the knees, keeping the back straight and '
            'head up.',
        'Eyes on the opponent\'s hips — they tell you where the body goes.',
      ],
      commonMistakes: [
        'Bending at the waist instead of the knees, which puts your head '
            'where they can front-headlock it.',
        'Looking down at the mat.',
      ],
      prescription: '4 × 30 s level changes on a whistle or timer, 30 s '
          'rest. Add a penetration step once the level change is smooth.',
    ),
    Drill(
      id: 'double_leg',
      discipline: DrillDiscipline.wrestling,
      sport: 'WRESTLING',
      title: 'Double Leg Takedown',
      summary: 'The highest-percentage takedown in wrestling and MMA.',
      level: DrillLevel.intermediate,
      needsPartner: true,
      keyPoints: [
        'Level change first, then a long penetration step between their '
            'feet.',
        'Head up and on the outside of their hip, chest to their thigh.',
        'Lock hands behind the knees and drive forward and across — '
            'finish at an angle.',
      ],
      commonMistakes: [
        'Shooting from too far away, with nothing to set it up.',
        'Head down in the middle, where it gets sprawled on or guillotined.',
      ],
      prescription: 'Partner drill: 5 sets of 5 reps each side at walking '
          'pace, then 3 × 1 min live finishes against light resistance.',
    ),
    Drill(
      id: 'sprawl',
      discipline: DrillDiscipline.wrestling,
      sport: 'WRESTLING',
      title: 'The Sprawl',
      summary: 'Your first line of takedown defence — and one of the best '
          'conditioning drills there is.',
      level: DrillLevel.fundamentals,
      keyPoints: [
        'Shoot the legs back and drop the hips hard onto their shoulders.',
        'Hands block the head and shoulders first.',
        'Stay on the balls of your feet, hips heavy, then circle to their '
            'back or stand up.',
      ],
      commonMistakes: [
        'Landing on the knees, which lets them keep driving.',
        'Sprawling and stopping — you have to circle off or get up.',
      ],
      prescription: '5 rounds of 30 s: sprawl and back to stance as fast as '
          'possible, 30 s rest. Partner shots once the solo form is clean.',
    ),

    // ── BJJ ───────────────────────────────────────────────────────────────
    Drill(
      id: 'shrimp',
      discipline: DrillDiscipline.bjj,
      sport: 'BJJ',
      title: 'Shrimp (Hip Escape)',
      summary: 'The movement behind almost every escape and guard recovery.',
      level: DrillLevel.fundamentals,
      starter: true,
      keyPoints: [
        'On your side, bottom leg bent, top foot planted.',
        'Push off the planted foot and drive the hips back, away from the '
            'opponent.',
        'Hands frame in front as if pushing someone away.',
        'Turn to the other side and repeat.',
      ],
      commonMistakes: [
        'Staying flat on the back — the hips can\'t move from there.',
        'Moving the shoulders instead of the hips.',
      ],
      prescription: '4 lengths of the mat, shrimping both sides. Add frames '
          'and a knee insert at the end of each rep once smooth.',
    ),
    Drill(
      id: 'closed_guard_posture',
      discipline: DrillDiscipline.bjj,
      sport: 'BJJ',
      title: 'Closed Guard: Break Posture',
      summary: 'From the bottom, nothing works until the opponent\'s posture '
          'is broken.',
      level: DrillLevel.fundamentals,
      needsPartner: true,
      keyPoints: [
        'Pull with the legs and the collar or head together to bring them '
            'forward.',
        'Keep the knees tight to their ribs so they can\'t sit back.',
        'Control an arm or the head once they\'re down — then attack.',
      ],
      commonMistakes: [
        'Pulling with the arms only; the legs do most of the work.',
        'Letting the guard open while you set up an attack.',
      ],
      prescription: 'Partner drill, 3 × 2 min: partner postures up, you '
          'break them down. Partner adds resistance each round.',
    ),
    Drill(
      id: 'mount_escape',
      discipline: DrillDiscipline.bjj,
      sport: 'BJJ',
      title: 'Mount Escape: Bridge & Roll',
      summary: 'Get out from under the worst position in grappling.',
      level: DrillLevel.intermediate,
      needsPartner: true,
      keyPoints: [
        'Trap one arm and the same-side foot so they can\'t post.',
        'Bridge high off both feet, straight up and over the trapped '
            'shoulder.',
        'Roll with them and land in their guard with good posture.',
      ],
      commonMistakes: [
        'Bridging without trapping the arm — they simply post and stay on.',
        'Bridging straight up instead of over the trapped side.',
      ],
      prescription: 'Partner drill: 3 sets of 8 escapes each side, then '
          '3 × 1 min positional rounds starting from mount.',
    ),
    Drill(
      id: 'technical_standup',
      discipline: DrillDiscipline.bjj,
      sport: 'BJJ',
      title: 'Technical Stand-Up',
      summary: 'Get back to your feet safely, guard up, without giving your '
          'back or your head.',
      level: DrillLevel.fundamentals,
      keyPoints: [
        'Post one hand behind you and the opposite foot in front.',
        'The other hand guards the face; the free leg stays ready to kick '
            'or frame.',
        'Lift the hips and swing the posted-side leg back under you.',
        'Land in stance, at range, not in front of them.',
      ],
      commonMistakes: [
        'Standing straight up, face-first toward the opponent.',
        'Putting both hands on the mat at once.',
      ],
      prescription: '3 sets of 10 each side, solo. Then from a seated start '
          'against a partner who closes distance.',
    ),

    // ── Clinch ────────────────────────────────────────────────────────────
    Drill(
      id: 'plum_knees',
      discipline: DrillDiscipline.clinch,
      sport: 'MUAY THAI',
      title: 'Plum Clinch & Knees',
      summary: 'Control the head and the posture follows — then knees land.',
      level: DrillLevel.fundamentals,
      starter: true,
      needsPartner: true,
      keyPoints: [
        'Hands stacked on the back of the head, not the neck.',
        'Forearms squeeze together in front of their collarbones.',
        'Pull the head down and step back to break their posture.',
        'Knees drive up and forward through the hips.',
      ],
      commonMistakes: [
        'Interlocking the fingers — it gives them something to break.',
        'Leaning in with the head up, which gives them the plum instead.',
      ],
      prescription: 'Partner drill, 3 × 2 min: control the plum, break '
          'posture, 3 knees, reset. Light contact.',
    ),
    Drill(
      id: 'pummeling',
      discipline: DrillDiscipline.clinch,
      sport: 'WRESTLING',
      title: 'Underhook Pummeling',
      summary: 'Win the inside position and you choose what happens next.',
      level: DrillLevel.intermediate,
      needsPartner: true,
      keyPoints: [
        'Swim the arm inside, with the elbow pinned to your own ribs.',
        'Head on their chest, hips close, knees bent.',
        'Keep your elbow tight after the underhook — a flared elbow gets '
            'whizzered.',
      ],
      commonMistakes: [
        'Reaching for the underhook with a straight arm.',
        'Standing tall, which lets them take the hips.',
      ],
      prescription: 'Partner drill: 3 × 1 min cooperative pummeling, then '
          '3 × 1 min competitive — first to double underhooks resets.',
    ),
  ];

  static List<Drill> byDiscipline(DrillDiscipline? discipline) =>
      discipline == null
          ? all
          : all.where((d) => d.discipline == discipline).toList();

  static Drill? byId(String id) {
    for (final drill in all) {
      if (drill.id == id) return drill;
    }
    return null;
  }
}
