// main.mbt
//
// Two-replica collaborative text editor. Alice and Bob start from a
// shared seed inserted by Alice. They then make concurrent edits and
// synchronise; both replicas converge on the same final text.

///|
fn append_text(
  r : @mbcrdt.RGA,
  text : String,
  actor : @mbcrdt.Actor,
) -> @mbcrdt.RGA {
  let mut cur = r
  for c in text {
    cur = cur.append(c, actor)
  }
  cur
}

///|
fn main {
  let alice = @mbcrdt.Actor::make("alice")
  let bob = @mbcrdt.Actor::make("bob")
  // Both replicas start with the same seed text inserted by Alice.
  // Bob's initial state is the result of merging Alice's seed with his
  // own empty state, so the two replicas agree on the initial text.
  let seed = "Hello!"
  let seed_rga = append_text(@mbcrdt.RGA::new(), seed, alice)
  let mut alice_doc = seed_rga
  let mut bob_doc = @mbcrdt.RGA::merge(@mbcrdt.RGA::new(), seed_rga)
  // Alice inserts " World" at the tail (after "Hello!").
  alice_doc = append_text(alice_doc, " World", alice)
  // Bob inserts "?" at the tail (after "Hello!").
  bob_doc = bob_doc.append('?', bob)
  // Synchronise both replicas.
  let alice_with_bob = @mbcrdt.RGA::merge(alice_doc, bob_doc)
  let bob_with_alice = @mbcrdt.RGA::merge(bob_doc, alice_doc)
  alice_doc = @mbcrdt.RGA::merge(alice_doc, alice_with_bob)
  bob_doc = @mbcrdt.RGA::merge(bob_doc, bob_with_alice)
  let a_text = alice_doc.to_string()
  let b_text = bob_doc.to_string()
  println("alice sees: \{a_text}")
  println("bob sees:   \{b_text}")
  if a_text == b_text {
    println("converged ✓")
  } else {
    println("diverged ✗")
  }
}
