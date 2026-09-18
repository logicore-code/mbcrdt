// or_set_test.mbt
//
// Black-box tests for the Observed-Remove Set. The key behavioural
// invariant is "concurrent add wins": if an add and a remove race, the
// add is preserved after both replicas have merged.

///|
test "or_set_add_and_contains" {
  let alice = Actor::make("alice")
  let s = ORSet::new()
    |> ORSet::add("alpha", alice)
    |> ORSet::add("beta", alice)
  assert_true(s.contains("alpha"))
  assert_true(s.contains("beta"))
  assert_false(s.contains("gamma"))
  assert_eq(s.size(), 2)
}

///|
test "or_set_remove_observed_tags" {
  let alice = Actor::make("alice")
  let s = ORSet::new() |> ORSet::add("x", alice) |> ORSet::remove("x")
  assert_false(s.contains("x"))
}

///|
test "or_set_concurrent_add_wins_over_remove" {
  // Replica A removes "x" while replica B concurrently adds "x". After
  // merging, the add must be preserved because the remove did not observe
  // the add's tag.
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = ORSet::new() |> ORSet::add("x", alice) |> ORSet::remove("x")
  let b = ORSet::new() |> ORSet::add("x", bob)
  let m = ORSet::merge(a, b)
  assert_true(m.contains("x"))
}

///|
test "or_set_merge_is_commutative" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = ORSet::new() |> ORSet::add("a", alice) |> ORSet::add("b", alice)
  let b = ORSet::new() |> ORSet::add("c", bob) |> ORSet::add("d", bob)
  let ab = ORSet::merge(a, b)
  let ba = ORSet::merge(b, a)
  assert_true(ORSet::equal(ab, ba))
}

///|
test "or_set_merge_is_idempotent" {
  let alice = Actor::make("alice")
  let a = ORSet::new() |> ORSet::add("a", alice) |> ORSet::add("b", alice)
  assert_true(ORSet::equal(ORSet::merge(a, a), a))
}

///|
test "or_set_converges_through_network_of_three_replicas" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let carol = Actor::make("carol")
  let mut a = ORSet::new() |> ORSet::add("a", alice)
  let mut b = ORSet::new() |> ORSet::add("b", bob)
  let mut c = ORSet::new() |> ORSet::add("c", carol)
  // pairwise sync
  let ab = ORSet::merge(a, b)
  let bc = ORSet::merge(b, c)
  let ac = ORSet::merge(a, c)
  a = ORSet::merge(ab, c)
  b = ORSet::merge(bc, a)
  c = ORSet::merge(ac, b)
  assert_true(ORSet::equal(a, b))
  assert_true(ORSet::equal(b, c))
  assert_eq(a.size(), 3)
}
