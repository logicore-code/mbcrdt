// main.mbt
//
// A tiny two-replica counter demo. The two replicas `alice` and `bob`
// each issue some local increments and decrements; we then synchronise
// them and verify that both replicas converge on the same value. This is
// the smallest useful end-to-end exercise of the `PNCounter` API.

///|
fn main {
  let alice = @mbcrdt.Actor::make("alice")
  let bob = @mbcrdt.Actor::make("bob")
  let mut a : @mbcrdt.PNCounter = @mbcrdt.PNCounter::new()
  let mut b : @mbcrdt.PNCounter = @mbcrdt.PNCounter::new()
  // Each replica issues a local-only edit.
  a = try @mbcrdt.PNCounter::inc(a, alice, delta=7) catch {
    _ => a
  } noraise {
    v => v
  }
  b = try @mbcrdt.PNCounter::inc(b, bob, delta=5) catch {
    _ => b
  } noraise {
    v => v
  }
  // Synchronise by taking the join on both sides.
  let joined = @mbcrdt.PNCounter::merge(a, b)
  a = @mbcrdt.PNCounter::merge(a, joined)
  b = @mbcrdt.PNCounter::merge(b, joined)
  let a_value = a.value()
  let b_value = b.value()
  println("alice sees: \{a_value}")
  println("bob sees:   \{b_value}")
  if a_value == b_value {
    println("converged ✓")
  } else {
    println("diverged ✗")
  }
}
