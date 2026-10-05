/// Synkregeln (Gör om #6): varje synkad post har en stämpel och kan vara en
/// tombstone; vid sammanslagning vinner senaste stämpeln PER POST. En regel för
/// allt — MK1 hade sju merge-funktioner med olika regler, och glappen gav buggar
/// (kroppsvikt där lokalt alltid vann 3.92.1, anteckningar som återuppstod 3.38.0).
///
/// Läs-före-skriv-grinden, CAS mot servern och själva sammanslagningen (senaste
/// stämpeln vinner, en tombstone hindrar återuppståndelse) bor i datalagret:
/// TableSync i sync_engine.dart. Här finns stämpeln och klockan de bygger på.
/// Tombstones rensas aldrig — de är små, och en rensad tombstone låter en enhet
/// som varit offline länge återuppliva raderat.
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

