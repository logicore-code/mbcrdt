// counter_wbtest.mbt
//
// White-box tests for the counter layer. White-box tests live in the same
// package as the implementation, which lets us construct read-only
// `CounterError` variants directly (blackbox tests cannot, because MoonBit
// forbids external construction of suberror constructors).

///|
test "describe_negative_grow_only_mentions_grow" {
  let s = CounterError::NegativeGrowOnly.describe()
  assert_true(s.contains("grow"))
}

///|
test "describe_negative_increment_mentions_inc" {
  let s = CounterError::NegativeIncrement.describe()
  assert_true(s.contains("inc"))
}

///|
test "describe_negative_decrement_mentions_dec" {
  let s = CounterError::NegativeDecrement.describe()
  assert_true(s.contains("dec"))
}

///|
test "contributions_exposes_per_actor_map" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let c = GCounter::new()
    |> GCounter::inc(alice, delta=2)
    |> GCounter::inc(bob, delta=4)
  let m = c.contributions()
  assert_eq(m.get("alice"), Some(2))
  assert_eq(m.get("bob"), Some(4))
  assert_eq(m.get("eve"), None)
}
