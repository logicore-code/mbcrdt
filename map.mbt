// map.mbt
//
// LWW-Map: a state-based key-value map where each key holds an
/// LWW-Register. Writes to the same key on different replicas resolve by
/// LWW timestamp; keys added on one side and removed on the other resolve
/// by tombstones (a per-key "deleted" flag with its own LWW timestamp).
///
/// References:
///   - Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
///     "A comprehensive study of Convergent and Commutative Replicated
///     Data Types." (INRIA TR 7506).

///|
/// A single entry inside an `LWWMap`. Either a live `value` with its
/// timestamp, or a tombstone (the key was deleted at the given time).
pub enum LWWMapEntry[V] {
  /// A live value with its LWW timestamp.
  Live(V, LWWTime)
  /// A tombstone: the key was deleted at the given timestamp.
  Tombstone(LWWTime)
}

///|
/// Return `true` iff the entry is a tombstone.
pub fn[V] LWWMapEntry::is_tombstone(self : LWWMapEntry[V]) -> Bool {
  match self {
    LWWMapEntry::Tombstone(_) => true
    _ => false
  }
}

///|
/// Return the underlying LWW timestamp of the entry.
pub fn[V] LWWMapEntry::time(self : LWWMapEntry[V]) -> LWWTime {
  match self {
    Live(_, t) => t
    Tombstone(t) => t
  }
}

///|
/// A Last-Writer-Wins Map. Keys are typed strings and values are any
/// type satisfying `Eq`. Each key maps to an `LWWMapEntry`; the merge
/// keeps the entry with the largest LWW timestamp.
pub struct LWWMap[V] {
  entries : Map[String, LWWMapEntry[V]]
  next_counter : Map[String, Int]
}

///|
/// Build an empty LWW-Map.
pub fn[V] LWWMap::new() -> LWWMap[V] {
  { entries: Map([]), next_counter: Map([]), }
}

///|
/// Build an LWW-Map from an initial collection of key-value pairs,
/// attributing every initial write to `actor`.
pub fn[V] LWWMap::of(pairs : Array[(String, V)], actor : Actor) -> LWWMap[V] {
  let mut m = LWWMap::new()
  for p in pairs {
    let (k, v) = p
    m = m.set(k, v, actor)
  }
  m
}

///|
/// Set the value of `key`. Returns a new map; the original is unchanged.
/// Subsequent writes by the same actor observe monotonically increasing
/// counters.
pub fn[V] LWWMap::set(
  self : LWWMap[V],
  key : String,
  value : V,
  actor : Actor,
) -> LWWMap[V] {
  let next = self.next_counter.get(actor.id()).unwrap_or(0) + 1
  let entries : Map[String, LWWMapEntry[V]] = Map([])
  for k, v in self.entries {
    entries.set(k, v)
  }
  let nc : Map[String, Int] = Map([])
  for k, v in self.next_counter {
    nc.set(k, v)
  }
  nc.set(actor.id(), next)
  let ts : LWWTime = { actor: actor.id(), counter: next, }
  entries.set(key, Live(value, ts))
  { entries, next_counter: nc, }
}

///|
/// Remove `key` by stamping a tombstone at the current time of `actor`.
pub fn[V] LWWMap::delete(
  self : LWWMap[V],
  key : String,
  actor : Actor,
) -> LWWMap[V] {
  let next = self.next_counter.get(actor.id()).unwrap_or(0) + 1
  let entries : Map[String, LWWMapEntry[V]] = Map([])
  for k, v in self.entries {
    entries.set(k, v)
  }
  let nc : Map[String, Int] = Map([])
  for k, v in self.next_counter {
    nc.set(k, v)
  }
  nc.set(actor.id(), next)
  let ts : LWWTime = { actor: actor.id(), counter: next, }
  entries.set(key, Tombstone(ts))
  { entries, next_counter: nc, }
}

///|
/// Read the value at `key`. Returns `None` if the key is absent or has
/// been tombstoned by a write that dominates the latest value write.
pub fn[V] LWWMap::get(self : LWWMap[V], key : String) -> V? {
  match self.entries.get(key) {
    Some(Live(v, _)) => Some(v)
    Some(Tombstone(_)) | None => None
  }
}

///|
/// `true` iff `key` has an entry (live or tombstoned) in this map.
pub fn[V] LWWMap::contains(self : LWWMap[V], key : String) -> Bool {
  self.entries.contains(key)
}

///|
/// Number of live keys (entries that are not pure tombstones).
pub fn[V] LWWMap::size(self : LWWMap[V]) -> Int {
  let mut n = 0
  for _, v in self.entries {
    match v {
      Live(_, _) => n = n + 1
      Tombstone(_) => ()
    }
  }
  n
}

///|
/// Materialise the live entries as an array of `(key, value)` pairs.
pub fn[V] LWWMap::to_array(self : LWWMap[V]) -> Array[(String, V)] {
  let out : Array[(String, V)] = []
  for k, v in self.entries {
    match v {
      Live(val, _) => out.push((k, val))
      Tombstone(_) => ()
    }
  }
  out
}

///|
/// Join-semilattice merge. For every key present in either side, keep
/// the entry with the larger LWW timestamp. The per-actor counter table
/// is merged component-wise to preserve future write ordering.
pub fn[V] LWWMap::merge(a : LWWMap[V], b : LWWMap[V]) -> LWWMap[V] {
  let entries : Map[String, LWWMapEntry[V]] = Map([])
  for k, v in a.entries {
    entries.set(k, v)
  }
  for k, vb in b.entries {
    let va = entries.get(k)
    let merged = match va {
      None => vb
      Some(va) => if LWWTime::greater(va.time(), vb.time()) { va } else { vb }
    }
    entries.set(k, merged)
  }
  let nc : Map[String, Int] = Map([])
  for k, v in a.next_counter {
    nc.set(k, v)
  }
  for k, v in b.next_counter {
    let cur = nc.get(k).unwrap_or(0)
    if v > cur {
      nc.set(k, v)
    }
  }
  { entries, next_counter: nc, }
}

///|
/// `true` iff both maps have the same live entries.
pub fn[V : Eq] LWWMap::equal(a : LWWMap[V], b : LWWMap[V]) -> Bool {
  let aa = a.to_array()
  let bb = b.to_array()
  if aa.length() != bb.length() {
    false
  } else {
    let mut ok = true
    for i in 0..<aa.length() {
      let (ka, va) = aa[i]
      let mut found_match = false
      for j in 0..<bb.length() {
        let (kb, vb) = bb[j]
        if ka == kb {
          found_match = true
          if va != vb {
            ok = false
          }
        }
      } nobreak {
        ()
      }
      if !found_match {
        ok = false
      }
    }
    ok
  }
}
