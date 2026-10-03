/// Synkmotorn: en tabell i taget, post för post.
///
/// Invarianter (Behåll, MK1 3.62.0):
///   1. LÄS FÖRE SKRIV: ingen push förrän en lyckad pull skett denna session.
///   2. Servern skyddar varje post: en skrivning tas bara emot om stämpeln är
///      nyare (mk2_push). En inaktuell skrivning hämtas om och slås ihop.
/// Regeln för sammanslagning är domänens (sync.dart): senaste stämpeln vinner.
library;

import '../domain/sync.dart';
import 'json_codec.dart';

/// En rad som den ser ut i Supabase-tabellerna.
class RemoteRow {
  const RemoteRow({required this.id, required this.stamp, required this.deleted, this.data, this.rev = 0});

  final String id;
  final Stamp stamp;
  final bool deleted;
  final Json? data;
  final int rev;

  Synced<Json> toSynced() => deleted ? Synced.deleted(id, stamp) : Synced(id, stamp, data);
}

class PushResult {
  const PushResult({required this.accepted, required this.stale});
  final List<String> accepted;
  final List<String> stale;
}

/// Servern. Implementeras av SupabaseRemote (riktig) och FakeRemote (tester).
abstract class Remote {
  Future<PushResult> push(String table, List<RemoteRow> rows);
  Future<List<RemoteRow>> pull(String table, int sinceRev);
}

/// En tabells lokala läge: poster, hämtmarkör och vad som väntar på att skickas.
class TableState {
  TableState({Map<String, Synced<Json>>? items, this.cursor = 0, Set<String>? dirty})
      : items = items ?? {},
        dirty = dirty ?? {};

  final Map<String, Synced<Json>> items;
  int cursor;
  final Set<String> dirty;
}

/// Lokal lagring (fil i appen, minne i tester).
abstract class LocalStore {
  Future<TableState> load(String table);
  Future<void> save(String table, TableState state);
}

class InMemoryLocalStore implements LocalStore {
  final _tables = <String, TableState>{};

  @override
  Future<TableState> load(String table) async {
    final s = _tables[table];
    if (s == null) return TableState();
    return TableState(items: {...s.items}, cursor: s.cursor, dirty: {...s.dirty});
  }

  @override
  Future<void> save(String table, TableState state) async {
    _tables[table] = TableState(items: {...state.items}, cursor: state.cursor, dirty: {...state.dirty});
  }
}

enum SyncOutcome { ok, offline, pushBlockedByGate }

class SyncReport {
  const SyncReport(this.outcome, {this.pulled = 0, this.pushed = 0, this.localChanged = false});
  final SyncOutcome outcome;
  final int pulled;
  final int pushed;

  /// Något från servern ändrade lokal data → UI:t ska läsa om.
  final bool localChanged;
}

class TableSync {
  TableSync(this.table, this.remote, this.store, this.clock);

  final String table;
  final Remote remote;
  final LocalStore store;
  final SyncClock clock;

  TableState _state = TableState();
  bool _pulledThisSession = false;

  bool get hasPulled => _pulledThisSession;
  Map<String, Synced<Json>> get items => Map.unmodifiable(_state.items);
  Iterable<Json> get liveValues => _state.items.values.where((s) => !s.isDeleted).map((s) => s.value!);
  int get pendingCount => _state.dirty.length;

  Future<void> open() async {
    _state = await store.load(table);
    for (final s in _state.items.values) {
      clock.observe(s.stamp);
    }
  }

  /// Lokal ändring. Sparas direkt lokalt (offline fungerar), skickas vid nästa sync.
  Future<void> put(String id, Json value, DateTime now) async {
    _state.items[id] = Synced(id, clock.tick(now), value);
    _state.dirty.add(id);
    await store.save(table, _state);
  }

  Future<void> remove(String id, DateTime now) async {
    if (!_state.items.containsKey(id)) return;
    _state.items[id] = Synced.deleted(id, clock.tick(now));
    _state.dirty.add(id);
    await store.save(table, _state);
  }

  Future<bool> _pull() async {
    final rows = await remote.pull(table, _state.cursor);
    var changed = false;
    for (final r in rows) {
      clock.observe(r.stamp);
      final incoming = r.toSynced();
      final local = _state.items[r.id];
      if (local == null || incoming.stamp > local.stamp) {
        _state.items[r.id] = incoming;
        _state.dirty.remove(r.id); // serverns version är nyare — vår väntande ändring är överspelad
        changed = true;
      } else if (incoming.stamp == local.stamp) {
        _state.dirty.remove(r.id); // redan på servern
      }
      if (r.rev > _state.cursor) _state.cursor = r.rev;
    }
    _pulledThisSession = true;
    return changed;
  }

  /// Hämta → slå ihop → skicka. Max två varv om servern svarar "inaktuell".
  Future<SyncReport> sync() async {
    var pulled = 0, pushed = 0, changed = false;
    try {
      for (var round = 0; round < 2; round++) {
        final before = _state.cursor;
        changed = await _pull() || changed;
        if (_state.cursor != before) pulled++;
        if (_state.dirty.isEmpty) break;
        final rows = [
          for (final id in _state.dirty)
            if (_state.items[id] case final s?)
              RemoteRow(id: id, stamp: s.stamp, deleted: s.isDeleted, data: s.value),
        ];
        final res = await remote.push(table, rows);
        // Bara det som skickades är kvitterat: en lokal ändring som kom under
        // pushen har nyare stämpel och ligger kvar som väntande.
        final sent = {for (final r in rows) r.id: r.stamp};
        for (final id in res.accepted) {
          if (_state.items[id]?.stamp == sent[id]) _state.dirty.remove(id);
        }
        pushed += res.accepted.length;
        if (res.stale.isEmpty) break;
      }
      await store.save(table, _state);
      return SyncReport(SyncOutcome.ok, pulled: pulled, pushed: pushed, localChanged: changed);
    } catch (_) {
      await store.save(table, _state);
      return SyncReport(_pulledThisSession ? SyncOutcome.offline : SyncOutcome.pushBlockedByGate,
          pulled: pulled, pushed: pushed, localChanged: changed);
    }
  }
}

/// Tabellnamnen i Supabase (supabase/001_mk2_schema.sql).
abstract final class Tables {
  static const workouts = 'mk2_workouts';
  static const program = 'mk2_program';
  static const bodyweight = 'mk2_bodyweight';
  static const notes = 'mk2_notes';
  static const exercises = 'mk2_exercises';
  static const settings = 'mk2_settings';
  static const all = [workouts, program, bodyweight, notes, exercises, settings];
}

class SyncEngine {
  SyncEngine({required this.remote, required this.store, required String deviceId})
      : clock = SyncClock(deviceId) {
    for (final t in Tables.all) {
      tables[t] = TableSync(t, remote, store, clock);
    }
  }

  final Remote remote;
  final LocalStore store;
  final SyncClock clock;
  final tables = <String, TableSync>{};

  TableSync operator [](String table) => tables[table]!;

  Future<void> open() async {
    for (final t in tables.values) {
      await t.open();
    }
  }

  Future<Map<String, SyncReport>> syncAll() async => {
        for (final t in tables.values) t.table: await t.sync(),
      };
}
