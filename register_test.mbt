// register_test.mbt
//
// Tests for the Last-Writer-Wins Register and the LWW-Map.

///|
test "lww_register_initial_value" {
  let alice = Actor::make("alice")
  let r = LWWRegister::new("hello", alice)
  assert_eq(r.value(), "hello")
}

///|
test "lww_register_write_updates_value" {
  let alice = Actor::make("alice")
  let r = LWWRegister::new("v0", alice) |> LWWRegister::write("v1")
  assert_eq(r.value(), "v1")
}

///|
test "lww_register_merge_keeps_latest_timestamp" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  // Alice's local clock is independent of Bob's; whichever has the larger
  // timestamp under the LWW order wins.
  let a = LWWRegister::new("from-alice", alice)
    |> LWWRegister::write("alice-late")
  let b = LWWRegister::new("from-bob", bob) |> LWWRegister::write("bob-late")
  let m = LWWRegister::merge(a, b)
  let winner = if LWWTime::greater(a.timestamp(), b.timestamp()) {
    "alice-late"
  } else {
    "bob-late"
  }
  assert_eq(m.value(), winner)
}

///|
test "lww_register_merge_is_idempotent" {
  let alice = Actor::make("alice")
  let r = LWWRegister::new("hello", alice) |> LWWRegister::write("world")
  assert_true(LWWRegister::equal(LWWRegister::merge(r, r), r))
}

///|
test "lww_register_merge_is_commutative" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = LWWRegister::new("a", alice) |> LWWRegister::write("a2")
  let b = LWWRegister::new("b", bob) |> LWWRegister::write("b2")
  let ab = LWWRegister::merge(a, b)
  let ba = LWWRegister::merge(b, a)
  assert_true(LWWRegister::equal(ab, ba))
}

///|
test "lww_map_set_and_get" {
  let alice = Actor::make("alice")
  let m = LWWMap::new()
    |> LWWMap::set("a", 1, alice)
    |> LWWMap::set("b", 2, alice)
  assert_eq(m.get("a"), Some(1))
  assert_eq(m.get("b"), Some(2))
  assert_eq(m.size(), 2)
}

///|
test "lww_map_delete_creates_tombstone" {
  let alice = Actor::make("alice")
  let m = LWWMap::new()
    |> LWWMap::set("a", 1, alice)
    |> LWWMap::delete("a", alice)
  assert_eq(m.get("a"), None)
  assert_eq(m.contains("a"), true)
}

///|
test "lww_map_concurrent_set_resolves_by_timestamp" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = LWWMap::new() |> LWWMap::set("x", "alice-value", alice)
  let b = LWWMap::new() |> LWWMap::set("x", "bob-value", bob)
  let m = LWWMap::merge(a, b)
  let live = m.to_array()
  // Exactly one of the two writes wins.
  assert_eq(live.length(), 1)
}

///|
test "lww_map_merge_is_commutative" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let a = LWWMap::new()
    |> LWWMap::set("k1", 1, alice)
    |> LWWMap::set("k2", 2, alice)
  let b = LWWMap::new()
    |> LWWMap::set("k3", 3, bob)
    |> LWWMap::delete("k1", bob)
  let ab = LWWMap::merge(a, b)
  let ba = LWWMap::merge(b, a)
  assert_true(LWWMap::equal(ab, ba))
}

///|
test "lww_map_converges_through_three_replicas" {
  let alice = Actor::make("alice")
  let bob = Actor::make("bob")
  let carol = Actor::make("carol")
  let mut a = LWWMap::new() |> LWWMap::set("a", 1, alice)
  let mut b = LWWMap::new() |> LWWMap::set("b", 2, bob)
  let mut c = LWWMap::new() |> LWWMap::set("c", 3, carol)
  let ab = LWWMap::merge(a, b)
  let bc = LWWMap::merge(b, c)
  let ac = LWWMap::merge(a, c)
  a = LWWMap::merge(ab, c)
  b = LWWMap::merge(bc, a)
  c = LWWMap::merge(ac, b)
  assert_true(LWWMap::equal(a, b))
  assert_true(LWWMap::equal(b, c))
  assert_eq(a.size(), 3)
}
