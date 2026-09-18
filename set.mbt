// set.mbt
//
// State-based set CRDTs. Three variants of increasing power:
//
//   - `GSet`    : grow-only set; elements can be added but never removed.
//   - `TwoPSet` : two-phase set, consisting of an `add` set and a `remove`
//                 set. Removed elements shadow concurrent adds in the merge
//                 step so the user can model "tombstone" semantics.
//   - `ORSet`   : observed-remove set. Each addition is tagged with a
//                 unique tag drawn from a causal context (actor + counter).
//                 A remove operation only observes the tags it has seen,
//                 which lets concurrent adds survive a remove. The OR-Set
//                 implementation lives in `or_set.mbt`.
//
// References:
//   - Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
//     "A comprehensive study of Convergent and Commutative Replicated
//     Data Types." (INRIA TR 7506).
//   - Bieniusa, A., Zawirski, M., Preguiça, N., Shapiro, M., Baquero, C.,
//     Balegas, V., Duarte, S. (2012). "An optimized conflict-free
//     replicated set."

///|
/// Errors emitted by the set layer.
pub suberror SetError {
  /// Attempted to remove an element that was never observed as added.
  TombstoneOverlap
}

///|
/// Internal helper: clone a set-typed map. We cannot share the underlying
/// `Map` between snapshots because `Map.set` mutates in place.
fn[T : Eq + Hash] clone_set(m : Map[T, Unit]) -> Map[T, Unit] {
  let out : Map[T, Unit] = Map([])
  for k, v in m {
    out.set(k, v)
  }
  out
}

///|
/// A grow-only set. Elements may be added but never removed; the merge
/// operation is the union of the two sets.
pub struct GSet[T] {
  elems : Map[T, Unit]
}

///|
/// Build an empty G-Set.
pub fn[T : Eq + Hash] GSet::new() -> GSet[T] {
  { elems: Map([]), }
}

///|
/// Build a G-Set from an initial collection of elements.
pub fn[T : Eq + Hash] GSet::of(items : ArrayView[T]) -> GSet[T] {
  let s = GSet::new()
  let mut out = s
  for x in items {
    out = out.add(x)
  }
  out
}

///|
/// Add an element to the set. Returns a new set so the original is not
/// mutated. This is a no-op if the element is already present.
pub fn[T : Eq + Hash] GSet::add(self : GSet[T], x : T) -> GSet[T] {
  if self.elems.contains(x) {
    self
  } else {
    let out : Map[T, Unit] = Map([])
    for k, v in self.elems {
      out.set(k, v)
    }
    out.set(x, ())
    { elems: out, }
  }
}

///|
/// Membership check.
pub fn[T : Eq + Hash] GSet::contains(self : GSet[T], x : T) -> Bool {
  self.elems.contains(x)
}

///|
/// Cardinality of the set.
pub fn[T] GSet::size(self : GSet[T]) -> Int {
  self.elems.length()
}

///|
/// Materialise the set as an array. Order is implementation-defined but
/// stable for a given snapshot.
pub fn[T] GSet::to_array(self : GSet[T]) -> Array[T] {
  self.elems.keys() |> Array::from_iter
}

///|
/// Join-semilattice merge: union of the two sets.
pub fn[T : Eq + Hash] GSet::merge(a : GSet[T], b : GSet[T]) -> GSet[T] {
  let out : Map[T, Unit] = Map([])
  for k, v in a.elems {
    out.set(k, v)
  }
  for k, v in b.elems {
    out.set(k, v)
  }
  { elems: out, }
}

///|
/// `true` iff both sets have exactly the same elements.
pub fn[T : Eq + Hash] GSet::equal(a : GSet[T], b : GSet[T]) -> Bool {
  a.elems == b.elems
}

///|
/// Two-Phase Set: each element exists either in the `add` set or the
/// `remove` set. An element that has been observed-removed is dropped from
/// the join, even if it was added concurrently on another replica.
pub struct TwoPSet[T] {
  adds : Map[T, Unit]
  removes : Map[T, Unit]
}

///|
/// Build an empty Two-Phase Set.
pub fn[T : Eq + Hash] TwoPSet::new() -> TwoPSet[T] {
  { adds: Map([]), removes: Map([]), }
}

///|
/// Build a Two-Phase Set from an initial collection.
pub fn[T : Eq + Hash] TwoPSet::of(items : ArrayView[T]) -> TwoPSet[T] {
  let s = TwoPSet::new()
  let mut out = s
  for x in items {
    out = out.add(x)
  }
  out
}

///|
/// Add an element. Idempotent.
pub fn[T : Eq + Hash] TwoPSet::add(self : TwoPSet[T], x : T) -> TwoPSet[T] {
  let adds : Map[T, Unit] = Map([])
  for k, v in self.adds {
    adds.set(k, v)
  }
  adds.set(x, ())
  { adds, removes: clone_set(self.removes), }
}

///|
/// Remove an element. An element removed on one replica is considered
/// removed by every replica after they have observed the removal event.
pub fn[T : Eq + Hash] TwoPSet::remove(
  self : TwoPSet[T],
  x : T,
) -> TwoPSet[T] raise SetError {
  if !self.adds.contains(x) {
    raise TombstoneOverlap
  }
  let removes : Map[T, Unit] = Map([])
  for k, v in self.removes {
    removes.set(k, v)
  }
  removes.set(x, ())
  { adds: clone_set(self.adds), removes, }
}

///|
/// Membership check after tombstones have been applied.
pub fn[T : Eq + Hash] TwoPSet::contains(self : TwoPSet[T], x : T) -> Bool {
  self.adds.contains(x) && !self.removes.contains(x)
}

///|
/// Cardinality of the visible elements (adds minus removes).
pub fn[T : Eq + Hash] TwoPSet::size(self : TwoPSet[T]) -> Int {
  let mut n = 0
  for k, _ in self.adds {
    if !self.removes.contains(k) {
      n = n + 1
    }
  }
  n
}

///|
/// Materialise the visible elements as an array.
pub fn[T : Eq + Hash] TwoPSet::to_array(self : TwoPSet[T]) -> Array[T] {
  let out : Array[T] = []
  for k, _ in self.adds {
    if !self.removes.contains(k) {
      out.push(k)
    }
  }
  out
}

///|
/// Merge two Two-Phase Sets: union the add-sets and union the remove-sets.
/// `add` operations concurrent with `remove` lose by design.
pub fn[T : Eq + Hash] TwoPSet::merge(
  a : TwoPSet[T],
  b : TwoPSet[T],
) -> TwoPSet[T] {
  let adds : Map[T, Unit] = Map([])
  for k, v in a.adds {
    adds.set(k, v)
  }
  for k, v in b.adds {
    adds.set(k, v)
  }
  let removes : Map[T, Unit] = Map([])
  for k, v in a.removes {
    removes.set(k, v)
  }
  for k, v in b.removes {
    removes.set(k, v)
  }
  { adds, removes, }
}

///|
/// `true` iff both sets have the same adds and removes.
pub fn[T : Eq + Hash] TwoPSet::equal(a : TwoPSet[T], b : TwoPSet[T]) -> Bool {
  a.adds == b.adds && a.removes == b.removes
}
