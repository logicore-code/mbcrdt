// or_set.mbt
//
// Observed-Remove Set (OR-Set). The standard state-based OR-Set keeps two
// maps: an `adds` map from `Dot` to a set of (element, tag) pairs, and a
// `removes` set of `Dot`s. A tag is "live" iff it is in `adds` and not
// in `removes`. An element is present iff at least one of its tags is
// live.
//
// To keep the API small, we expose the conventional `add`/`remove`/
// `contains` interface but internally track tags using the dot-based
// causal context in `dot.mbt`.
//
// References:
//   - Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
//     "A comprehensive study of Convergent and Commutative Replicated
//     Data Types." (INRIA TR 7506).

///|
/// An OR-Set is the join of an `adds` map of `Dot → (element, observed)`
/// and a causal context of observed removals. The set of "live" tags is the
/// set of dots in `adds` minus the dots covered by `removes`.
pub struct ORSet[T] {
  // For every element `v`, we keep a map of tag → () recording the live
  // tags that introduced `v`. We also keep a flat set of all retired
  // tags in `retired` so that the merge can retire new tags without
  // losing the causal information required for future tombstones.
  adds : Map[T, Map[Dot, Unit]]
  retired : CausalContext
  clock : CausalContext
} derive(Debug)

///|
/// Build an empty OR-Set.
pub fn[T : Eq + Hash] ORSet::new() -> ORSet[T] {
  { adds: Map([]), retired: CausalContext::new(), clock: CausalContext::new(), }
}

///|
/// Build an OR-Set from an initial collection.
pub fn[T : Eq + Hash] ORSet::of(
  items : ArrayView[T],
  actor : Actor,
) -> ORSet[T] {
  let s = ORSet::new()
  let mut out = s
  for x in items {
    out = out.add(x, actor)
  }
  out
}

///|
/// Snapshot the current clock and return an `ORSet` with `x` tagged by a
/// fresh dot.
pub fn[T : Eq + Hash] ORSet::add(
  self : ORSet[T],
  x : T,
  actor : Actor,
) -> ORSet[T] {
  let (clock, dot) = self.clock.next(actor)
  let bag : Map[Dot, Unit] = match self.adds.get(x) {
    Some(m) => {
      let out : Map[Dot, Unit] = Map([])
      for k, v in m {
        out.set(k, v)
      }
      out
    }
    None => Map([])
  }
  bag.set(dot, ())
  let adds : Map[T, Map[Dot, Unit]] = Map([])
  for k, v in self.adds {
    adds.set(k, v)
  }
  adds.set(x, bag)
  { adds, retired: self.retired, clock, }
}

///|
/// Remove `x` by retiring every live tag currently associated with it. A
/// remove that races with a concurrent add keeps the new tag, because the
/// new tag was not in the bag at remove time.
pub fn[T : Eq + Hash] ORSet::remove(self : ORSet[T], x : T) -> ORSet[T] {
  let adds : Map[T, Map[Dot, Unit]] = Map([])
  for k, v in self.adds {
    adds.set(k, v)
  }
  let mut retired = self.retired
  match self.adds.get(x) {
    Some(bag) => {
      let live_bag : Map[Dot, Unit] = Map([])
      for d, _ in bag {
        // A tag is "retired" only if it is not strictly greater than the
        // current clock for its actor; otherwise the tag belongs to a
        // concurrent operation that we cannot retroactively remove.
        let cur = self.clock.to_map().get(d.actor).unwrap_or(0)
        if d.counter > cur {
          live_bag.set(d, ())
        } else {
          retired = retired.observe(d)
        }
      }
      adds.set(x, live_bag)
    }
    None => ()
  }
  { adds, retired, clock: self.clock, }
}

///|
/// Membership check: the element is present iff at least one of its
/// tags is live (i.e. it was added and never retired).
pub fn[T : Eq + Hash] ORSet::contains(self : ORSet[T], x : T) -> Bool {
  let retired = self.retired.to_map()
  let mut found = false
  match self.adds.get(x) {
    Some(bag) =>
      for d, _ in bag {
        let cur = retired.get(d.actor).unwrap_or(0)
        if d.counter > cur {
          found = true
          break
        }
      } nobreak {
        ()
      }
    None => ()
  }
  found
}

///|
/// Cardinality of the visible elements.
pub fn[T : Eq + Hash] ORSet::size(self : ORSet[T]) -> Int {
  let mut n = 0
  for k, _ in self.adds {
    if self.contains(k) {
      n = n + 1
    }
  }
  n
}

///|
/// Materialise the visible elements as an array.
pub fn[T : Eq + Hash] ORSet::to_array(self : ORSet[T]) -> Array[T] {
  let out : Array[T] = []
  for k, _ in self.adds {
    if self.contains(k) {
      out.push(k)
    }
  }
  out
}

///|
/// Merge two OR-Sets component-wise and recompute the retired context
/// as the join of the two retired contexts. The clock is also joined.
pub fn[T : Eq + Hash] ORSet::merge(a : ORSet[T], b : ORSet[T]) -> ORSet[T] {
  let adds : Map[T, Map[Dot, Unit]] = Map([])
  for k, v in a.adds {
    let bag : Map[Dot, Unit] = Map([])
    for d, _ in v {
      bag.set(d, ())
    }
    adds.set(k, bag)
  }
  for k, v in b.adds {
    let bag = match adds.get(k) {
      Some(m) => m
      None => Map([])
    }
    for d, _ in v {
      bag.set(d, ())
    }
    adds.set(k, bag)
  }
  {
    adds,
    retired: CausalContext::join(a.retired, b.retired),
    clock: CausalContext::join(a.clock, b.clock),
  }
}

///|
/// `true` iff both sets have the same tags and causal context.
pub fn[T : Eq + Hash] ORSet::equal(a : ORSet[T], b : ORSet[T]) -> Bool {
  a.adds == b.adds &&
  CausalContext::equal(a.retired, b.retired) &&
  CausalContext::equal(a.clock, b.clock)
}
