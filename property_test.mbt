// property_test.mbt
//
// Property-based tests for the core CRDT invariants. Rather than rely on
// a random generator, we exercise the algebraic laws on a few small,
// hand-written scenarios that are easy to read and cover all branches.
// Adding a real `quickcheck`-style generator is a worthwhile next step
// once the project depends on `moonbitlang/core/quickcheck`.

///|
test "prop_g_counter_merge_is_a_lattice_join" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let carol = Actor::make("carol")
  let mut a = GCounter::new()
  let mut b = GCounter::new()
  let mut c = GCounter::new()
  a = a.inc(alice, delta=1).inc(bob, delta=2)
  b = b.inc(bob, delta=1).inc(carol, delta=3)
  c = c.inc(alice, delta=5)
  // (a ∨ b) ∨ c == a ∨ (b ∨ c) for any join-semilattice.
  let lhs = GCounter::merge(GCounter::merge(a, b), c)
  let rhs = GCounter::merge(a, GCounter::merge(b, c))
  assert_eq(GCounter::equal(lhs, rhs), true)
}

///|
test "prop_g_counter_merge_idempotent_on_three_replicas" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let carol = Actor::make("carol")
  let mut a = GCounter::new()
  let mut b = GCounter::new()
  let mut c = GCounter::new()
  a = a.inc(alice, delta=2)
  b = b.inc(bob, delta=3)
  c = c.inc(carol, delta=5)
  // Pairwise sync simulated as `(merge(merge(a, b), c))`.
  let joined = GCounter::merge(GCounter::merge(a, b), c)
  // Idempotent: joining again with any replica leaves the state stable.
  assert_eq(GCounter::equal(GCounter::merge(joined, a), joined), true)
  assert_eq(GCounter::equal(GCounter::merge(joined, b), joined), true)
  assert_eq(GCounter::equal(GCounter::merge(joined, c), joined), true)
}

///|
test "prop_pn_counter_balance_is_preserved_by_merge" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let mut a = PNCounter::new()
  let mut b = PNCounter::new()
  a = a.inc(alice, delta=10).dec(alice, delta=3)
  b = b.inc(bob, delta=7).dec(bob, delta=2)
  // Sum is 10-3 + 7-2 = 12 before merge.
  let pre_a = a.value()
  let pre_b = b.value()
  let m = PNCounter::merge(a, b)
  // Sum is preserved by the join: pre_a + pre_b == m.value().
  assert_eq(m.value(), pre_a + pre_b)
}

///|
test "prop_g_set_merge_is_union" {
  let a = GSet::of(["x", "y", "z"][:])
  let b = GSet::of(["y", "z", "w"][:])
  let m = GSet::merge(a, b)
  // The merge result is exactly the union of the two input sets.
  for k in ["x", "y", "z", "w"] {
    assert_eq(m.contains(k), true)
  }
  assert_eq(m.size(), 4)
}

///|
test "prop_or_set_concurrent_add_survives_remove" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let mut a = ORSet::new()
  let mut b = ORSet::new()
  a = a.add("x", alice)
  a = a.remove("x")
  b = b.add("x", bob)
  let m = ORSet::merge(a, b)
  assert_eq(m.contains("x"), true)
}

///|
test "prop_lww_register_winner_independent_of_sync_order" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = LWWRegister::new("v0", alice) |> LWWRegister::write("v1")
  let b = LWWRegister::new("v0", bob) |> LWWRegister::write("v1")
  // Different actors → both win, but both have the same value "v1" so
  // the result is uniquely "v1" regardless of merge order.
  let ab = LWWRegister::merge(a, b)
  let ba = LWWRegister::merge(b, a)
  assert_eq(ab.value(), "v1")
  assert_eq(ba.value(), "v1")
  assert_eq(LWWRegister::equal(ab, ba), true)
}

///|
test "prop_lww_map_commutative_under_concurrent_deletes" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = LWWMap::new()
    |> LWWMap::set("k1", 1, alice)
    |> LWWMap::delete("k2", alice)
  let b = LWWMap::new()
    |> LWWMap::set("k2", 2, bob)
    |> LWWMap::delete("k1", bob)
  let ab = LWWMap::merge(a, b)
  let ba = LWWMap::merge(b, a)
  assert_true(LWWMap::equal(ab, ba))
}
