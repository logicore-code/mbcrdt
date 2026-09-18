// counter_test.mbt
//
// Black-box tests for the G-Counter and PN-Counter. Each test pins a
// concrete behavioural property the counter layer must guarantee. Tests
// that need to construct read-only `CounterError` variants directly live
// in `counter_wbtest.mbt`, where the package boundary allows it.

///|
test "g_counter_starts_at_zero" {
  let c = GCounter::new()
  assert_eq(c.value(), 0)
}

///|
test "g_counter_increments_track_per_actor" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let c = GCounter::new()
    |> GCounter::inc(alice, delta=3)
    |> GCounter::inc(bob, delta=5)
  assert_eq(c.value(), 8)
}

///|
test "g_counter_inc_with_default_delta_is_one" {
  let alice = Actor::make("alice")
  let c = GCounter::new() |> GCounter::inc(alice)
  assert_eq(c.value(), 1)
}

///|
test "g_counter_merge_takes_per_actor_max" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = GCounter::new()
    |> GCounter::inc(alice, delta=3)
    |> GCounter::inc(bob, delta=2)
  let b = GCounter::new()
    |> GCounter::inc(alice, delta=5)
    |> GCounter::inc(bob, delta=1)
  let m = GCounter::merge(a, b)
  // alice: max(3, 5) = 5, bob: max(2, 1) = 2, total 7
  assert_eq(m.value(), 7)
}

///|
test "g_counter_merge_is_commutative" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = GCounter::new()
    |> GCounter::inc(alice, delta=3)
    |> GCounter::inc(bob, delta=2)
  let b = GCounter::new()
    |> GCounter::inc(alice, delta=5)
    |> GCounter::inc(bob, delta=1)
  assert_eq(GCounter::equal(GCounter::merge(a, b), GCounter::merge(b, a)), true)
}

///|
test "g_counter_merge_is_idempotent" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = GCounter::new()
    |> GCounter::inc(alice, delta=3)
    |> GCounter::inc(bob, delta=2)
  assert_eq(GCounter::equal(GCounter::merge(a, a), a), true)
}

///|
test "g_counter_merge_is_associative" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let carol = Actor::make("carol")
  let a = GCounter::new() |> GCounter::inc(alice, delta=1)
  let b = GCounter::new() |> GCounter::inc(bob, delta=2)
  let c = GCounter::new() |> GCounter::inc(carol, delta=4)
  let lhs = GCounter::merge(GCounter::merge(a, b), c)
  let rhs = GCounter::merge(a, GCounter::merge(b, c))
  assert_eq(GCounter::equal(lhs, rhs), true)
}

///|
test "g_counter_does_not_alias_underlying_map" {
  let alice = Actor::make("alice")
  let a = GCounter::new() |> GCounter::inc(alice, delta=3)
  let b = GCounter::inc(a, alice, delta=5)
  let a2 = GCounter::inc(a, Actor::make("eve"), delta=10)
  assert_eq(a.value(), 3)
  assert_eq(b.value(), 8)
  assert_eq(a2.value(), 13)
}

///|
test "pn_counter_balances_increments_and_decrements" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let c = PNCounter::new()
    |> PNCounter::inc(alice, delta=7)
    |> PNCounter::inc(bob, delta=3)
    |> PNCounter::dec(alice, delta=2)
  assert_eq(c.value(), 8)
}

///|
test "pn_counter_merge_sums_independent_updates" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = PNCounter::new() |> PNCounter::inc(alice, delta=5)
  let b = PNCounter::new()
    |> PNCounter::inc(bob, delta=3)
    |> PNCounter::dec(alice, delta=1)
  let m = PNCounter::merge(a, b)
  assert_eq(m.value(), 7)
}

///|
test "pn_counter_merge_is_idempotent" {
  let alice = Actor::make("alice")
  let a = PNCounter::new()
    |> PNCounter::inc(alice, delta=5)
    |> PNCounter::dec(alice, delta=2)
  assert_eq(PNCounter::equal(PNCounter::merge(a, a), a), true)
}

///|
test "describe_is_dispatched_for_each_variant" {
  // Verifies that the catch arm of `try` correctly receives the variant
  // for each kind of invalid argument. The actual string content is
  // covered in counter_wbtest.mbt.
  let alice = Actor::make("alice")
  let c = GCounter::new()
  let desc : String = try GCounter::inc(c, alice, delta=-1) catch {
    CounterError::NegativeGrowOnly => "matched grow-only branch"
    _ => "wrong branch"
  } noraise {
    _ => "unreachable"
  }
  assert_eq(desc, "matched grow-only branch")
}

///|
test "pn_counter_rejects_negative_increment_in_catch" {
  let alice = Actor::make("alice")
  let c = PNCounter::new()
  let desc : String = try PNCounter::inc(c, alice, delta=-1) catch {
    CounterError::NegativeIncrement => "matched negative-increment branch"
    _ => "wrong branch"
  } noraise {
    _ => "unreachable"
  }
  assert_eq(desc, "matched negative-increment branch")
}

///|
test "pn_counter_rejects_negative_decrement_in_catch" {
  let alice = Actor::make("alice")
  let c = PNCounter::new()
  let desc : String = try PNCounter::dec(c, alice, delta=-1) catch {
    CounterError::NegativeDecrement => "matched negative-decrement branch"
    _ => "wrong branch"
  } noraise {
    _ => "unreachable"
  }
  assert_eq(desc, "matched negative-decrement branch")
}
