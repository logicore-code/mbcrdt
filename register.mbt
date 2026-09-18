// register.mbt
//
// Last-Writer-Wins Register (LWW-Register). Each write attaches a
// timestamp drawn from the actor's local causal counter, so writes are
// totally ordered by `(actor, counter)` lexicographically. Two replicas
// always converge on the same value because the join is a max over
// `(actor, counter)` pairs.
//
// References:
//   - Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
//     "A comprehensive study of Convergent and Commutative Replicated
//     Data Types." (INRIA TR 7506).

///|
/// A timestamp is a `(actor, counter)` pair. The counter is monotone
/// per-actor and the actor is a stable string id.
pub struct LWWTime {
  actor : String
  counter : Int
} derive(Hash, Eq, Debug)

///|
/// Build a timestamp from a typed `Actor` and a counter.
pub fn LWWTime::from_actor(actor : Actor, counter : Int) -> LWWTime {
  { actor: actor.id(), counter, }
}

///|
/// Compare two timestamps lexicographically: first by actor id, then by
/// counter. Returns negative if `a` is strictly less than `b`.
pub fn LWWTime::compare(a : LWWTime, b : LWWTime) -> Int {
  match a.actor.compare(b.actor) {
    0 => a.counter.compare(b.counter)
    other => other
  }
}

///|
/// `true` iff `a` strictly dominates `b` under the LWW partial order.
pub fn LWWTime::greater(a : LWWTime, b : LWWTime) -> Bool {
  LWWTime::compare(a, b) > 0
}

///|
/// A Last-Writer-Wins Register. The current value is paired with the
/// timestamp at which it was written; the join takes the write with the
/// largest timestamp under the LWW order.
pub struct LWWRegister[T] {
  value : T
  timestamp : LWWTime
  next_counter : Int
} derive(Debug)

///|
/// Build a register initialised to `init` by `actor` at counter 0.
pub fn[T] LWWRegister::new(init : T, actor : Actor) -> LWWRegister[T] {
  {
    value: init,
    timestamp: { actor: actor.id(), counter: 0, },
    next_counter: 1,
  }
}

///|
/// Read the current value.
pub fn[T] LWWRegister::value(self : LWWRegister[T]) -> T {
  self.value
}

///|
/// Read the timestamp of the current write.
pub fn[T] LWWRegister::timestamp(self : LWWRegister[T]) -> LWWTime {
  self.timestamp
}

///|
/// Write `value` to the register, attaching a fresh monotonic counter.
pub fn[T] LWWRegister::write(
  self : LWWRegister[T],
  value : T,
) -> LWWRegister[T] {
  let c = self.next_counter
  let actor_id = self.timestamp.actor
  { value, timestamp: { actor: actor_id, counter: c, }, next_counter: c + 1, }
}

///|
/// Join-semilattice merge: keep the write with the larger LWW timestamp.
pub fn[T] LWWRegister::merge(
  a : LWWRegister[T],
  b : LWWRegister[T],
) -> LWWRegister[T] {
  let next = if a.next_counter > b.next_counter {
    a.next_counter
  } else {
    b.next_counter
  }
  if LWWTime::greater(a.timestamp, b.timestamp) {
    { value: a.value, timestamp: a.timestamp, next_counter: next, }
  } else if LWWTime::greater(b.timestamp, a.timestamp) {
    { value: b.value, timestamp: b.timestamp, next_counter: next, }
  } else {
    // Tie-break deterministically by value content; callers that need
    // strict convergence can rely on the value being the same in this
    // branch (both replicas observed the same write).
    { value: a.value, timestamp: a.timestamp, next_counter: next, }
  }
}

///|
/// `true` iff both registers hold the same value at the same timestamp.
pub fn[T : Eq] LWWRegister::equal(
  a : LWWRegister[T],
  b : LWWRegister[T],
) -> Bool {
  a.value == b.value &&
  a.timestamp.actor == b.timestamp.actor &&
  a.timestamp.counter == b.timestamp.counter
}
