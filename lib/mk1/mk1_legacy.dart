/// KARANTÄN — MK1:s hårdkodade program och namnalias, kopierade ur index.html.
/// Behövs bara för att tolka MK1-data under övergången. Raderas med mk1_codec
/// den dag hemsidan stängs. Får ALDRIG importeras av lib/domain/.
library;

class LegacySlot {
  const LegacySlot(this.id, this.name, {this.ramp = false, this.uni = false, this.bw = false, this.timed = false});
  final String id;
  final String name;
  final bool ramp, uni, bw, timed;
}

class LegacySession {
  const LegacySession(this.id, this.name, this.slots);
  final String id;
  final String name;
  final List<LegacySlot> slots;
}

const legacyDefaultSessionOrder = ['A', 'B', 'C', 'D', 'E', 'F'];
const legacyDefaultRestSlots = [6];

/// BASE_SESSIONS (A–F) + SESSION_TEMPLATES (G–N). Mallarnas A–F är identiska med basen.
const legacySessions = <LegacySession>[
  LegacySession('A', 'Chest + Tri', [
    LegacySlot('A1', 'Bench Press (BB)', ramp: true),
    LegacySlot('A2', 'Incline Press (Smith)'),
    LegacySlot('A3', 'Flyes (Cable)'),
    LegacySlot('A4', 'Tricep Pushdowns'),
  ]),
  LegacySession('B', 'Back Heavy + Biceps', [
    LegacySlot('B1', 'Dead Hang', bw: true, timed: true),
    LegacySlot('B2', 'Deadlift', ramp: true),
    LegacySlot('B3', 'Unilateral Row (Cable)', uni: true),
    LegacySlot('B4', 'Lat Prayers'),
  ]),
  LegacySession('C', 'Legs + Calfs', [
    LegacySlot('C1', 'Zercher Squat', ramp: true),
    LegacySlot('C2', 'Lying Leg Curl'),
    LegacySlot('C3', 'Leg Extension'),
    LegacySlot('C4', 'Seated Calf Raise'),
  ]),
  LegacySession('D', 'Shoulders + Traps', [
    LegacySlot('D1', 'Military Press (BB)', ramp: true),
    LegacySlot('D2', 'Lateral Raises (DB)'),
    LegacySlot('D3', 'Face Pulls'),
    LegacySlot('D4', 'External Rotator Cuff'),
  ]),
  LegacySession('E', 'Chest pt. 2', [
    LegacySlot('E1', 'Bench Press (DB)', ramp: true),
    LegacySlot('E2', 'Decline Press (Smith)'),
    LegacySlot('E3', 'Flyes (Cable)'),
    LegacySlot('E4', 'Overhead Tricep Extension'),
  ]),
  LegacySession('F', 'Back pt. 2', [
    LegacySlot('F1', 'Pull-ups', bw: true),
    LegacySlot('F2', 'Unilateral Row (Cable)', uni: true),
    LegacySlot('F3', 'Shrugs (DB)'),
    LegacySlot('F4', 'Lat Prayers'),
  ]),
  LegacySession('G', 'Arms', [
    LegacySlot('G1', 'Biceps Curl (BB)'),
    LegacySlot('G2', 'Hammer Curl'),
    LegacySlot('G3', 'Tricep Pushdowns'),
    LegacySlot('G4', 'Overhead Tricep Extension'),
  ]),
  LegacySession('H', 'Full Body', [
    LegacySlot('H1', 'Deadlift', ramp: true),
    LegacySlot('H2', 'Military Press (BB)', ramp: true),
    LegacySlot('H3', 'Pull-ups', bw: true),
    LegacySlot('H4', 'Dips', bw: true),
  ]),
  LegacySession('I', 'Cardio / Conditioning', [
    LegacySlot('I1', 'Bike Cardio', timed: true),
    LegacySlot('I2', 'Farmers Walk'),
    LegacySlot('I3', 'Sled Push'),
  ]),
  LegacySession('J', 'Glutes + Hamstrings', [
    LegacySlot('J1', 'Romanian Deadlift', ramp: true),
    LegacySlot('J2', 'Hip Thrust'),
    LegacySlot('J3', 'Lying Leg Curl'),
    LegacySlot('J4', 'Nordic Curl'),
  ]),
  LegacySession('K', 'Core + Abs', [
    LegacySlot('K1', 'Ab Wheel'),
    LegacySlot('K2', 'Hanging Leg Raise'),
    LegacySlot('K3', 'Cable Crunch'),
    LegacySlot('K4', 'Dead Bug'),
  ]),
  LegacySession('L', 'Upper Body Push', [
    LegacySlot('L1', 'Military Press (BB)', ramp: true),
    LegacySlot('L2', 'Shoulder Press (DB)'),
    LegacySlot('L3', 'Lateral Raises (DB)'),
    LegacySlot('L4', 'Tricep Pushdowns'),
  ]),
  LegacySession('M', 'Upper Body Pull', [
    LegacySlot('M1', 'Pull-ups', bw: true),
    LegacySlot('M2', 'Seated Row (Cable)'),
    LegacySlot('M3', 'Face Pulls'),
    LegacySlot('M4', 'Biceps Curl (BB)'),
  ]),
  LegacySession('N', 'Custom Session', [
    LegacySlot('N1', 'Exercise 1'),
    LegacySlot('N2', 'Exercise 2'),
    LegacySlot('N3', 'Exercise 3'),
    LegacySlot('N4', 'Exercise 4'),
  ]),
];

LegacySession? legacySession(String id) {
  for (final s in legacySessions) {
    if (s.id == id) return s;
  }
  return null;
}

/// NAME_ALIASES — gamla namn kedjar till kanoniska (canonicalName loopar).
const legacyNameAliases = <String, String>{
  'Flat BB': 'Flat BB Bench Press', 'Flat DB': 'Flat DB Press', 'Seated Calf Raises': 'Seated Calf Raise',
  'Military Press': 'Military Press (barbell)', 'Shrugs': 'DB Shrugs', 'Pull-ups': 'Pull-ups (pronated)',
  'Incline Smith or Incline DB': 'Incline Smith Press', 'Pec Deck / Cable Flyes': 'Cable Flyes',
  'Chins or Pullups': 'Pull-ups', 'Decline Smith / DB': 'Decline Smith Press', 'Pull-ups / Chins': 'Pull-ups',
  'Tri-finisher (Pushdowns/Overhead)': 'Tricep Pushdowns', 'Tri-finisher (Pushdowns)': 'Overhead Tricep Extension',
  'Calfs (standing + seated)': 'Seated Calf Raise', 'Calfs': 'Seated Calf Raise',
  'Lateral Raises DB/Cable': 'Lateral Raises', 'Helms Rear Delt Row / Face Pulls': 'Face Pulls',
  'Cable Rotator Cuff': 'External Rotator Cuff', 'Rotator Cuff': 'External Rotator Cuff',
  'Flat BB Bench Press': 'Bench Press (BB)', 'Flat DB Press': 'Bench Press (DB)',
  'Incline BB Press': 'Incline Press (BB)', 'Incline DB Press': 'Incline Press (DB)',
  'Incline Smith Press': 'Incline Press (Smith)',
  'Decline Cable Press': 'Decline Press (Cable)', 'Decline DB Press': 'Decline Press (DB)',
  'Decline Smith Press': 'Decline Press (Smith)',
  'Cable Flyes': 'Flyes (Cable)', 'Incline Cable Flyes': 'Incline Flyes (Cable)',
  'Decline Cable Flyes': 'Decline Flyes (Cable)', 'Single-Arm Cable Flyes': 'Single-Arm Flyes (Cable)',
  'Seated Cable Row': 'Seated Row (Cable)', 'Seated Row': 'Seated Row (Machine)',
  'Unilateral Cable Row': 'Unilateral Row (Cable)',
  'Cable Lateral Raises': 'Lateral Raises (Cable)', 'Lateral Raises': 'Lateral Raises (DB)',
  'Military Press (barbell)': 'Military Press (BB)', 'Military Press - Smith': 'Military Press (Smith)',
  'DB Shoulder Press': 'Shoulder Press (DB)', 'Standing Cable Front Raise': 'Front Raise (Cable)',
  'Rear Delt Flyes': 'Rear Delt Flyes (DB)',
  'Barbell Curl': 'Biceps Curl (BB)', 'Cable Curl': 'Biceps Curl (Cable)', 'DB Curl': 'Biceps Curl (DB)',
  'Incline DB Curl': 'Incline Biceps Curl (DB)',
  'Barbell Shrugs': 'Shrugs (BB)', 'DB Shrugs': 'Shrugs (DB)', 'Trap Bar Shrugs': 'Shrugs (Trap Bar)',
  'Vader (seated)': 'Seated Calf Raise', 'Vader (standing)': 'Standing Calf Raise',
};

const legacySlotNameAliases = <String, String>{
  'A4|Tri-finisher': 'Tricep Pushdowns',
  'E4|Tri-finisher': 'Overhead Tricep Extension',
  'C4|Calfs': 'Seated Calf Raise',
};

/// MK1:s canonicalName.
String legacyCanonicalName(String name, [String? slotId]) {
  if (slotId != null) {
    final s = legacySlotNameAliases['$slotId|$name'];
    if (s != null) return s;
  }
  var cur = name;
  for (var i = 0; i < 8; i++) {
    final next = legacyNameAliases[cur];
    if (next == null) break;
    cur = next;
  }
  return cur;
}
