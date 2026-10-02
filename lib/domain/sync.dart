/// Synkregeln (Gör om #6): varje synkad post har en stämpel och kan vara en
/// tombstone; vid sammanslagning vinner senaste stämpeln PER POST. En regel för
/// allt — MK1 hade sju merge-funktioner med olika regler, och glappen gav buggar
/// (kroppsvikt där lokalt alltid vann 3.92.1, anteckningar som återuppstod 3.38.0).
///
/// Läs-före-skriv-grinden och CAS mot servern hör till datalagret (F2) och är
/// oförändrade invarianter (Behåll). Det här är regeln de bär.
library;

/// Hybrid-stämpel: väggtid + räknare + enhet. Tiden går aldrig bakåt på en enhet
/// (även om telefonens klocka gör det), och lika stämplar avgörs deterministiskt
/// så att merge(a, b) == merge(b, a) på alla enheter.
class Stamp implements Comparable<Stamp> {
  const Stamp(this.wallMs, this.counter, this.node);

  final int wallMs;
  final int counter;
  final String node;

  static const zero = Stamp(0, 0, '');

  @override
  int compareTo(Stamp o) {
    if (wallMs != o.wallMs) return wallMs.compareTo(o.wallMs);
    if (counter != o.counter) return counter.compareTo(o.counter);
    return node.compareTo(o.node);
  }

  bool operator >(Stamp o) => compareTo(o) > 0;

  @override
  bool operator ==(Object other) =>
      other is Stamp && other.wallMs == wallMs && other.counter == counter && other.node == node;

  @override
  int get hashCode => Object.hash(wallMs, counter, node);

  @override
  String toString() => '$wallMs:$counter:$node';
}

/// Klockan på en enhet. [tick] ger en stämpel för en lokal ändring; [observe]
/// tar höjd för stämplar från andra enheter så att nästa lokala ändring alltid
/// hamnar efter allt den här enheten har sett.
class SyncClock {
  SyncClock(this.node, [this._last = Stamp.zero]);

  final String node;
  Stamp _last;

  Stamp get last => _last;

  Stamp tick(DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    _last = ms > _last.wallMs ? Stamp(ms, 0, node) : Stamp(_last.wallMs, _last.counter + 1, node);
    return _last;
  }

  void observe(Stamp remote) {
    if (remote > _last) _last = Stamp(remote.wallMs, remote.counter, node);
  }
}

/// En synkad post. [value] är null för en tombstone.
class Synced<T> {
  const Synced(this.id, this.stamp, this.value);
  const Synced.deleted(this.id, this.stamp) : value = null;

  final String id;
  final Stamp stamp;
  final T? value;

  bool get isDeleted => value == null;
}

class MergeResult<T> {
  const MergeResult(this.merged, {required this.localChanged, required this.remoteBehind});

  final Map<String, Synced<T>> merged;

  /// Något från den andra sidan vann → lokal data behöver uppdateras.
  final bool localChanged;

  /// Lokalt finns något nyare än molnet → det behöver skickas.
  final bool remoteBehind;
}

/// Slår ihop två samlingar post för post. Senaste stämpeln vinner, oavsett om
/// den är en ändring eller en radering. En tombstone hindrar återuppståndelse;
/// en NYARE ändring efter raderingen är en legitim återskapning.
MergeResult<T> mergeSynced<T>(Map<String, Synced<T>> local, Map<String, Synced<T>> remote) {
  final out = <String, Synced<T>>{};
  var localChanged = false, remoteBehind = false;
  for (final id in {...local.keys, ...remote.keys}) {
    final l = local[id], r = remote[id];
    if (l == null) {
      out[id] = r!;
      localChanged = true;
    } else if (r == null) {
      out[id] = l;
      remoteBehind = true;
    } else if (r.stamp > l.stamp) {
      out[id] = r;
      localChanged = true;
    } else {
      out[id] = l;
      if (l.stamp > r.stamp) remoteBehind = true;
    }
  }
  return MergeResult(out, localChanged: localChanged, remoteBehind: remoteBehind);
}

/// Rensar tombstones äldre än [ttl]. MK1 körde 30 dagar; en enhet som varit
/// offline längre än så kan då återuppliva raderat. Standard här: 180 dagar.
Map<String, Synced<T>> purgeTombstones<T>(
  Map<String, Synced<T>> items,
  DateTime now, {
  Duration ttl = const Duration(days: 180),
}) {
  final cutoff = now.subtract(ttl).millisecondsSinceEpoch;
  return {
    for (final e in items.entries)
      if (!(e.value.isDeleted && e.value.stamp.wallMs < cutoff)) e.key: e.value,
  };
}
