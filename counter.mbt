// counter.mbt
//
// State-based grow-only and positive-negative counters (CvRDT-style). These
// are the simplest illustrations of CRDT reasoning: each replica owns its
// own counter cell and the merge operation is the per-cell maximum, which
// forms a join-semilattice over the map of replicas.
//
// References:
//   - Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
//     "A comprehensive study of Convergent and Commutative Replicated
//     Data Types." (INRIA TR 7506).
//   - Baquero, C., Almeida, P., Cunha, A. (2024). "The Algebra of CRDTs."

///|
/// Stable identifier for a replica that contributes to a counter.
///
/// Wrapping the underlying primitive in a nominal struct means two replicas
/// that happen to share a numeric id are still distinguishable at the type
/// level, and prevents accidental cross-domain id reuse.
pub struct Actor(String) derive(Hash, Eq, Debug)

///|
/// Build an `Actor` from any string-like id (replica uuid, username, etc).
pub fn Actor::make(id : String) -> Actor {
  Actor(id)
}

///|
/// Borrow the underlying id as a string.
pub fn Actor::id(self : Actor) -> String {
  let Actor(s) = self
  s
}

///|
/// Errors emitted by the counter layer.
pub suberror CounterError {
  /// Attempted to grow a G-Counter with a negative delta.
  NegativeGrowOnly
  /// Attempted to pass a negative increment to a PN-Counter.
  NegativeIncrement
  /// Attempted to pass a negative decrement to a PN-Counter.
  NegativeDecrement
}

///|
/// Concise one-line description, suitable for panic-style error chains.
pub fn CounterError::describe(self : CounterError) -> String {
  match self {
    NegativeGrowOnly => "G-Counter is grow-only: pass a non-negative delta"
    NegativeIncrement =>
      "PN-Counter::inc expects a non-negative delta; use dec for negative deltas"
    NegativeDecrement =>
      "PN-Counter::dec expects a non-negative delta; use inc for positive deltas"
  }
}

///|
/// A grow-only counter, also known as a G-Counter. Each replica owns its
/// own counter cell and only ever increments it. Merging two replicas takes
/// the per-cell maximum.
pub struct GCounter {
  counts : Map[String, Int]
} derive(Eq, Debug)

///|
/// Build an empty G-Counter.
pub fn GCounter::new() -> GCounter {
  { counts: Map([]), }
}

///|
/// Defensive copy of the inner map so that two replicas sharing a struct
/// never observe each other's mutations.
fn clone_counts(m : Map[String, Int]) -> Map[String, Int] {
  let out : Map[String, Int] = Map([])
  for k, v in m {
    out.set(k, v)
  }
  out
}

///|
/// Increment `self` for the given `actor` by `delta`. The default delta is
/// `1`; passing a negative value violates the G-Counter contract and is
/// rejected with a `CounterError`.
pub fn GCounter::inc(
  self : GCounter,
  actor : Actor,
  delta? : Int = 1,
) -> GCounter raise CounterError {
  if delta < 0 {
    raise NegativeGrowOnly
  }
  let Actor(id) = actor
  let out = clone_counts(self.counts)
  let cur = out.get(id).unwrap_or(0)
  out.set(id, cur + delta)
  { counts: out, }
}

///|
/// Read the total value as the sum across replicas.
pub fn GCounter::value(self : GCounter) -> Int {
  let mut sum = 0
  for _, v in self.counts {
    sum = sum + v
  }
  sum
}

///|
/// Per-replica contribution map. Useful for debugging convergence properties
/// or for serialising the counter to a JSON-like payload.
pub fn GCounter::contributions(self : GCounter) -> Map[String, Int] {
  clone_counts(self.counts)
}

///|
/// Join-semilattice merge: take the per-actor maximum. Because the operation
/// only depends on the two operands and never on ordering or timing, the
/// merge is provably commutative, associative, and idempotent.
pub fn GCounter::merge(a : GCounter, b : GCounter) -> GCounter {
  let out = clone_counts(a.counts)
  for k, v in b.counts {
    let prev = out.get(k).unwrap_or(0)
    if v > prev {
      out.set(k, v)
    }
  }
  { counts: out, }
}

///|
/// `true` iff both counters agree on the per-replica contribution map.
pub fn GCounter::equal(a : GCounter, b : GCounter) -> Bool {
  a.counts == b.counts
}

///|
/// A Positive-Negative Counter. Maintains two G-Counters internally: `p`
/// tracks all `inc` operations and `n` tracks all `dec` operations. The
/// value is `sum(p) - sum(n)`.
pub struct PNCounter {
  p : GCounter
  n : GCounter
} derive(Eq, Debug)

///|
/// Build an empty PN-Counter.
pub fn PNCounter::new() -> PNCounter {
  { p: GCounter::new(), n: GCounter::new(), }
}

///|
/// Increment the counter for the given actor.
pub fn PNCounter::inc(
  self : PNCounter,
  actor : Actor,
  delta? : Int = 1,
) -> PNCounter raise CounterError {
  if delta < 0 {
    raise NegativeIncrement
  }
  { p: GCounter::inc(self.p, actor, delta~), n: self.n, }
}

///|
/// Decrement the counter for the given actor. The decrement is recorded in
/// the negative half so that decrements commute with concurrent increments.
pub fn PNCounter::dec(
  self : PNCounter,
  actor : Actor,
  delta? : Int = 1,
) -> PNCounter raise CounterError {
  if delta < 0 {
    raise NegativeDecrement
  }
  { p: self.p, n: GCounter::inc(self.n, actor, delta~), }
}

///|
/// Net value of the PN-Counter: `Σp - Σn`.
pub fn PNCounter::value(self : PNCounter) -> Int {
  self.p.value() - self.n.value()
}

///|
/// Per-replica positive and negative contribution maps. Mostly used by
/// tests that probe the strong-join-semilattice property.
pub fn PNCounter::contributions(
  self : PNCounter,
) -> (Map[String, Int], Map[String, Int]) {
  (self.p.contributions(), self.n.contributions())
}

///|
/// Merge two PN-Counters componentwise.
pub fn PNCounter::merge(a : PNCounter, b : PNCounter) -> PNCounter {
  { p: GCounter::merge(a.p, b.p), n: GCounter::merge(a.n, b.n), }
}

///|
/// `true` iff both halves of the PN-Counter are equal.
pub fn PNCounter::equal(a : PNCounter, b : PNCounter) -> Bool {
  a.p == b.p && a.n == b.n
}
