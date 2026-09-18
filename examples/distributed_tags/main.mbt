// main.mbt
//
// Two-replica tag store. Alice and Bob each maintain a local ORSet of
// tags, then we exercise three interesting scenarios:
//
//   1. Concurrent adds of the same tag from both replicas converge to a
//      single live entry.
//   2. Concurrent adds of distinct tags yield the union.
//   3. A remove racing with a concurrent add keeps the add (observed-
//      remove semantics).

///|
fn main {
  let alice = @mbcrdt.Actor::make("alice")
  let bob = @mbcrdt.Actor::make("bob")

  // Scenario 1: concurrent same-tag adds.
  let mut a1 = @mbcrdt.ORSet::new() |> @mbcrdt.ORSet::add("rust", alice)
  let mut b1 = @mbcrdt.ORSet::new() |> @mbcrdt.ORSet::add("rust", bob)
  a1 = @mbcrdt.ORSet::merge(a1, b1)
  b1 = @mbcrdt.ORSet::merge(b1, a1)
  println("concurrent-same-tag size: \{a1.size()}")

  // Scenario 2: distinct tags from each replica.
  let a2 = @mbcrdt.ORSet::new()
    |> @mbcrdt.ORSet::add("crdt", alice)
    |> @mbcrdt.ORSet::add("moonbit", alice)
  let b2 = @mbcrdt.ORSet::new()
    |> @mbcrdt.ORSet::add("distributed", bob)
    |> @mbcrdt.ORSet::add("moonbit", bob)
  let merged2 = @mbcrdt.ORSet::merge(a2, b2)
  println("distinct-tags size: \{merged2.size()}")

  // Scenario 3: remove racing with concurrent add.
  let mut a3 = @mbcrdt.ORSet::new() |> @mbcrdt.ORSet::add("feature-flag", alice)
  let b3 = @mbcrdt.ORSet::new() |> @mbcrdt.ORSet::add("feature-flag", bob)
  a3 = a3.remove("feature-flag")
  let merged3 = @mbcrdt.ORSet::merge(a3, b3)
  println("remove-then-add-survives: \{merged3.contains("feature-flag")}")
}
