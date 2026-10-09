/// "What's new" (Niklas 2026-10-07): en ruta EN gång efter att appen
/// uppdaterats till en ny stable-version — det stora, inte varje detalj.
/// Stängs bara med OK eller SKIP (tid att läsa); ett tryck räcker för att den
/// inte kommer igen förrän nästa version med en ny text. Ingen "Don't show
/// again" (Niklas 2026-10-07: överflödig när rutan ändå visas en gång per
/// version). Bara i STABLE; DEV ser allt ändå (förhandsvisning via DEV-knappen
/// på kedjevyn).
///
/// Minnet ligger på telefonen, inte i kontots synkade data: rutan visas en
/// gång per enhet och kommer aldrig tillbaka via en synk.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Texten för en release. [build] = första bygget den gäller; den visas för
/// den som kör ett bygge ≥ [build] och inte har sett den. Engelska (app-språket),
/// godkänd av Niklas före släppet.
class WhatsNewNote {
  const WhatsNewNote({required this.build, required this.points});
  final int build;
  final List<String> points;
}

/// Nyast sist. Lägg till en ny post inför varje stable-släpp som har något stort.
const whatsNewNotes = [
  WhatsNewNote(build: 107, points: [
    'Round complete: close a round and get a summary of it — sessions, sets, new PRs and days.',
    'One device at a time: signing in on a new device asks before the other one is signed out.',
    'Delete a mis-logged set, or all history for an exercise, from Progress — with undo.',
    'Vibration on/off under Settings › Training & App Functions.',
    'DONE moves the finished exercise to the top, with the next one right below.',
  ]),
  WhatsNewNote(build: 109, points: [
    'New theme: Cosmic Horror — pick it under Settings › Appearance.',
    'Rest timer: the alarm plays in your headphones when they are connected, and the timer starts after every set, warm-ups included.',
    'Tap the rest-over screen to jump straight into the app. DISMISS keeps you where you are, and a locked phone stays locked until you unlock it.',
    'Create your own exercise from any exercise picker — "New exercise" at the top, or "Create" from the search.',
    'Report a problem in Settings opens an email with your build and phone details filled in.',
  ]),
];

/// Det som sparas på telefonen.
abstract class WhatsNewStore {
  /// Senaste bygget vars ruta visats (eller tyst markerats), null = aldrig.
  Future<int?> lastSeen();
  Future<void> markSeen(int build);
}

class PrefsWhatsNewStore implements WhatsNewStore {
  static const _seenKey = 'whats_new_seen';

  @override
  Future<int?> lastSeen() async => (await SharedPreferences.getInstance()).getInt(_seenKey);

  @override
  Future<void> markSeen(int build) async => (await SharedPreferences.getInstance()).setInt(_seenKey, build);
}

/// Tester.
class MemoryWhatsNewStore implements WhatsNewStore {
  MemoryWhatsNewStore({this.seen});
  int? seen;

  @override
  Future<int?> lastSeen() async => seen;
  @override
  Future<void> markSeen(int build) async => seen = build;
}

/// Vad som ska hända vid start.
sealed class WhatsNewDecision {
  const WhatsNewDecision();
}

class WhatsNewNothing extends WhatsNewDecision {
  const WhatsNewNothing();
}

/// Markera tyst (helt ny användare: inget att jämföra med — välkomstvyn tar över).
class WhatsNewSilent extends WhatsNewDecision {
  const WhatsNewSilent(this.build);
  final int build;
}

class WhatsNewShow extends WhatsNewDecision {
  const WhatsNewShow(this.note);
  final WhatsNewNote note;
}

/// Ren logik (testas utan telefon). [hasHistory] skiljer en uppdaterande
/// användare (har tränat) från en helt ny, som båda saknar [lastSeen].
WhatsNewDecision decideWhatsNew({
  required int build,
  required int? lastSeen,
  required bool hasHistory,
  List<WhatsNewNote> notes = whatsNewNotes,
}) {
  if (build <= 0) return const WhatsNewNothing();
  WhatsNewNote? newest;
  for (final n in notes) {
    if (n.build <= build && (lastSeen == null || n.build > lastSeen)) newest = n;
  }
  if (newest == null) return const WhatsNewNothing();
  if (lastSeen == null && !hasHistory) return WhatsNewSilent(build);
  return WhatsNewShow(newest);
}
