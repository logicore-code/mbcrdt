// set_test.mbt
//
// Black-box tests for the G-Set and Two-Phase Set. Property-based
// invariants (commutativity, associativity, idempotence of the merge) are
// exercised by the deterministic test harness; a randomised property suite
// lives in `property_test.mbt`.

///|
test "g_set_add_and_contains" {
  let s = GSet::of(["alpha", "beta", "gamma"][:])
  assert_true(s.contains("alpha"))
  assert_true(s.contains("beta"))
  assert_true(s.contains("gamma"))
  assert_false(s.contains("delta"))
}

///|
test "g_set_add_is_idempotent" {
  let a = GSet::new() |> GSet::add("a")
  let b = a |> GSet::add("a")
  assert_eq(a.size(), 1)
  assert_eq(b.size(), 1)
  assert_true(GSet::equal(a, b))
}

///|
test "g_set_merge_is_union" {
  let a = GSet::of(["x", "y"][:])
  let b = GSet::of(["y", "z"][:])
  let m = GSet::merge(a, b)
  assert_eq(m.size(), 3)
  assert_true(m.contains("x"))
  assert_true(m.contains("y"))
  assert_true(m.contains("z"))
}

///|
test "g_set_merge_is_commutative" {
  let a = GSet::of(["x", "y"][:])
  let b = GSet::of(["y", "z"][:])
  assert_true(GSet::equal(GSet::merge(a, b), GSet::merge(b, a)))
}

///|
test "g_set_merge_is_idempotent" {
  let a = GSet::of(["x", "y"][:])
  assert_true(GSet::equal(GSet::merge(a, a), a))
}

///|
test "two_p_set_add_and_remove" {
  let s = TwoPSet::of(["a", "b", "c"][:]) |> TwoPSet::remove("b")
  assert_true(s.contains("a"))
  assert_false(s.contains("b"))
  assert_true(s.contains("c"))
  assert_eq(s.size(), 2)
}

///|
test "two_p_set_remove_unknown_raises" {
  let s = TwoPSet::of(["a"][:])
  let outcome : String = try TwoPSet::remove(s, "b") catch {
    SetError::TombstoneOverlap => "rejected"
    _ => "wrong"
  } noraise {
    _ => "unreachable"
  }
  assert_eq(outcome, "rejected")
}

///|
test "two_p_set_remove_wins_after_merge" {
  // After both replicas have observed each other's state, removing on
  // either side should keep the element removed in the join.
  let a = TwoPSet::of(["x"][:]) |> TwoPSet::remove("x")
  let b = TwoPSet::of(["x"][:])
  let m = TwoPSet::merge(a, b)
  assert_false(m.contains("x"))
}

///|
test "two_p_set_concurrent_add_loses_to_remove" {
  // Replica `a` removes "x" before seeing replica `b`'s concurrent add.
  // The remove tombstones the element, so the add is lost after merge.
  let a = TwoPSet::of(["x"][:]) |> TwoPSet::remove("x")
  let b = TwoPSet::of(["x"][:])
  let m = TwoPSet::merge(a, b)
  assert_false(m.contains("x"))
}

///|
test "two_p_set_merge_is_commutative" {
  let a = TwoPSet::of(["x"][:]) |> TwoPSet::remove("x")
  let b = TwoPSet::of(["y", "z"][:])
  let ab = TwoPSet::merge(a, b)
  let ba = TwoPSet::merge(b, a)
  assert_true(TwoPSet::equal(ab, ba))
}
