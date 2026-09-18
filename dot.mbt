// dot.mbt
//
// Dot-based causal context, used to power `ORSet` (observed-remove set)
// and `RGA` (replicated growable array).
//
// A `Dot` is a pair `(actor_id, sequence_number)` that uniquely identifies
// a single event emitted by a given replica. The `CausalContext` (a.k.a.
// version vector) tracks the largest sequence number observed from every
// actor; it is used to causally order operations without a global clock.
//
// References:
//   - Baquero, C., Almeida, P., Cunha, A. (2024). "The Algebra of CRDTs."
//   - Almeida, P., Shoker, A., Baquero, C. (2018). "Delta State Replicated
//     Data Types." (Journal of Parallel and Distributed Computing).

///|
/// A single causal event: "actor `s` produced event number `n`". `Dot`s
/// are totally ordered lexicographically: `(s1, n1) < (s2, n2)` iff
/// `s1 < s2` or `s1 == s2` and `n1 < n2`.
pub struct Dot {
  actor : String
  counter : Int
} derive(Hash, Eq, Debug)

///|
/// Build a new dot. The counter should normally be issued by the actor's
/// local clock, which is monotonic per replica.
pub fn Dot::new(actor : String, counter : Int) -> Dot {
  { actor, counter, }
}

///|
/// Build a dot from a typed `Actor` identifier.
pub fn Dot::from_actor(actor : Actor, counter : Int) -> Dot {
  Dot::new(actor.id(), counter)
}

///|
/// Borrow the actor id of this dot.
pub fn Dot::id(self : Dot) -> String {
  self.actor
}

///|
/// Borrow the sequence counter of this dot.
pub fn Dot::counter(self : Dot) -> Int {
  self.counter
}

///|
/// Lexicographic comparison of two dots.
pub fn Dot::compare(a : Dot, b : Dot) -> Int {
  match a.actor.compare(b.actor) {
    0 => a.counter.compare(b.counter)
    other => other
  }
}

///|
/// `true` iff `a` is strictly less than `b`.
pub fn Dot::less(a : Dot, b : Dot) -> Bool {
  Dot::compare(a, b) < 0
}

///|
/// `true` iff the two dots refer to the same event.
pub fn Dot::equal(a : Dot, b : Dot) -> Bool {
  a.actor == b.actor && a.counter == b.counter
}

///|
/// A causal context (a.k.a. version vector) maps each actor id to the
/// greatest counter that this replica has observed from that actor. The
/// context is partial-ordered component-wise: `c1 ≤ c2` iff for every
/// actor `a`, `c1[a] ≤ c2[a]`.
pub struct CausalContext {
  map : Map[String, Int]
} derive(Eq, Debug)

///|
/// Build an empty causal context.
pub fn CausalContext::new() -> CausalContext {
  { map: Map([]), }
}

///|
/// Defensive copy of the underlying map.
fn clone_clock(m : Map[String, Int]) -> Map[String, Int] {
  let out : Map[String, Int] = Map([])
  for k, v in m {
    out.set(k, v)
  }
  out
}

///|
/// Component-wise maximum of two causal contexts.
pub fn CausalContext::join(
  a : CausalContext,
  b : CausalContext,
) -> CausalContext {
  let out = clone_clock(a.map)
  for k, v in b.map {
    let prev = out.get(k).unwrap_or(0)
    if v > prev {
      out.set(k, v)
    }
  }
  { map: out, }
}

///|
/// Component-wise minimum of two causal contexts.
pub fn CausalContext::meet(
  a : CausalContext,
  b : CausalContext,
) -> CausalContext {
  let out : Map[String, Int] = Map([])
  for k, va in a.map {
    match b.map.get(k) {
      Some(vb) =>
        if va == vb {
          out.set(k, va)
        } else if va < vb {
          out.set(k, va)
        } else {
          out.set(k, vb)
        }
      None => ()
    }
  }
  { map: out, }
}

///|
/// `true` iff `a` dominates `b` (i.e. `a ≥ b` for every actor).
pub fn CausalContext::dominates(a : CausalContext, b : CausalContext) -> Bool {
  for k, vb in b.map {
    let va = a.map.get(k).unwrap_or(0)
    if va < vb {
      return false
    }
  } nobreak {
    true
  }
}

///|
/// `true` iff the two contexts are incomparable (neither dominates).
pub fn CausalContext::concurrent(a : CausalContext, b : CausalContext) -> Bool {
  !CausalContext::dominates(a, b) && !CausalContext::dominates(b, a)
}

///|
/// `true` iff the two contexts are equal component-wise.
pub fn CausalContext::equal(a : CausalContext, b : CausalContext) -> Bool {
  a.map == b.map
}

///|
/// Advance the counter for the given actor by one and return the resulting
/// dot. Useful for tagging operations as they are produced.
pub fn CausalContext::next(
  self : CausalContext,
  actor : Actor,
) -> (CausalContext, Dot) {
  let Actor(id) = actor
  let out = clone_clock(self.map)
  let cur = out.get(id).unwrap_or(0)
  let next = cur + 1
  out.set(id, next)
  ({ map: out, }, { actor: id, counter: next, })
}

///|
/// Observe a dot, advancing the counter for its actor. Calling this on a
/// dot already covered by the context is a no-op.
pub fn CausalContext::observe(self : CausalContext, d : Dot) -> CausalContext {
  let out = clone_clock(self.map)
  let cur = out.get(d.actor).unwrap_or(0)
  if d.counter > cur {
    out.set(d.actor, d.counter)
  }
  { map: out, }
}

///|
/// Observe every dot in the iterator, advancing the counter for each.
pub fn CausalContext::observe_all(
  self : CausalContext,
  dots : Iter[Dot],
) -> CausalContext {
  let mut out = self
  for d in dots {
    out = out.observe(d)
  }
  out
}

///|
/// Borrow the raw counter map. Useful for serialisation and tests.
pub fn CausalContext::to_map(self : CausalContext) -> Map[String, Int] {
  clone_clock(self.map)
}
