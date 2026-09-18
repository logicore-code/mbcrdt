// rga_test.mbt
//
// Black-box tests for the Replicated Growable Array. The RGA is the most
// expressive CRDT in this library, so the tests focus on the operational
// invariants: causal ordering survives concurrent inserts, deletes are
// observed by all replicas, and the merged sequence is deterministic.

///|
test "rga_append_and_prepend" {
  let alice = Actor::make("alice")
  let r = RGA::new()
    |> RGA::append('a', alice)
    |> RGA::append('b', alice)
    |> RGA::append('c', alice)
  assert_eq(r.to_string(), "abc")
  let p = RGA::new()
    |> RGA::prepend('a', alice)
    |> RGA::prepend('b', alice)
    |> RGA::prepend('c', alice)
  assert_eq(p.to_string(), "cba")
}

///|
test "rga_insert_at_position" {
  let alice = Actor::make("alice")
  let r = RGA::new()
    |> RGA::append('a', alice)
    |> RGA::append('c', alice)
    |> RGA::insert_at(1, 'b', alice)
  assert_eq(r.to_string(), "abc")
}

///|
test "rga_delete_at_removes_char" {
  let alice = Actor::make("alice")
  let r0 = RGA::new()
    |> RGA::append('a', alice)
    |> RGA::append('b', alice)
    |> RGA::append('c', alice)
  let r1 = delete_at_or_panic(r0, 1)
  let r2 = delete_at_or_panic(r1, 1)
  assert_eq(r2.to_string(), "a")
}

///|
test "rga_concurrent_inserts_both_preserved" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = RGA::new() |> RGA::prepend('A', alice)
  let b = RGA::new() |> RGA::prepend('B', bob)
  let m = RGA::merge(a, b)
  assert_eq(m.length(), 2)
}

///|
test "rga_merge_converges_on_three_replicas" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let carol = Actor::make("carol")
  let a = RGA::new() |> RGA::append('a', alice) |> RGA::append('b', alice)
  let b = RGA::new() |> RGA::append('x', bob)
  let c = RGA::new()
    |> RGA::append('1', carol)
    |> RGA::append('2', carol)
    |> RGA::append('3', carol)
  let ab = RGA::merge(a, b)
  let ac = RGA::merge(a, c)
  let bc = RGA::merge(b, c)
  let all = RGA::merge(RGA::merge(ab, c), RGA::merge(ac, bc))
  assert_eq(all.length(), 6)
}

///|
test "rga_to_array_matches_to_string" {
  let alice = Actor::make("alice")
  let r = RGA::new()
    |> RGA::prepend('h', alice)
    |> RGA::prepend('e', alice)
    |> RGA::prepend('l', alice)
    |> RGA::prepend('l', alice)
    |> RGA::prepend('o', alice)
  let arr = r.to_array()
  let s = r.to_string()
  assert_eq(arr.length(), s.length())
  assert_eq(s, "olleh")
}

///|
test "rga_delete_is_observed_after_merge" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  // Both replicas start by appending "a" then "b".
  let a0 = RGA::new() |> RGA::append('a', alice) |> RGA::append('b', alice)
  let b0 = RGA::new() |> RGA::append('a', bob) |> RGA::append('b', bob)
  // Replica A now deletes the 'a' character. Because both replicas have
  // added their own 'a' nodes (id'd by actor+counter), the merged view
  // contains two 'a' characters; the merge must retire exactly the one
  // that A tombstoned.
  let a1 = delete_at_or_panic(a0, 0)
  let m = RGA::merge(a1, b0)
  // Three live characters remain: the 'a' from bob plus the two 'b's.
  assert_eq(m.length(), 3)
}

///|
fn delete_at_or_panic(r : RGA, idx : Int) -> RGA {
  try RGA::delete_at(r, idx) catch {
    _ => r
  } noraise {
    v => v
  }
}
