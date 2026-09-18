// dot_test.mbt
//
// Tests for the dot-based causal context that powers OR-Set and RGA.

///|
test "dot_compare_is_lexicographic" {
  let a = Dot::new("aaa", 3)
  let b = Dot::new("aaa", 5)
  let c = Dot::new("bbb", 1)
  assert_eq(Dot::compare(a, b) < 0, true)
  assert_eq(Dot::compare(b, a) > 0, true)
  // 'a' < 'b', so a < c regardless of counter.
  assert_eq(Dot::compare(a, c) < 0, true)
  assert_eq(Dot::compare(c, a) > 0, true)
  assert_eq(Dot::compare(a, a), 0)
}

///|
test "dot_from_actor_matches_new" {
  let alice = Actor::make("alice")
  let d = Dot::from_actor(alice, 7)
  assert_eq(d.id(), "alice")
  assert_eq(d.counter(), 7)
}

///|
test "causal_context_join_takes_per_actor_max" {
  let mut a = CausalContext::new()
  a = ctx_inc(a, "alice", 3)
  a = ctx_inc(a, "bob", 2)
  let mut b = CausalContext::new()
  b = ctx_inc(b, "alice", 5)
  b = ctx_inc(b, "carol", 7)
  let j = CausalContext::join(a, b)
  let m = j.to_map()
  assert_eq(m.get("alice"), Some(5))
  assert_eq(m.get("bob"), Some(2))
  assert_eq(m.get("carol"), Some(7))
}

///|
test "causal_context_dominates_partial_order" {
  let mut a = CausalContext::new()
  let mut b = CausalContext::new()
  a = ctx_inc(a, "alice", 5)
  b = ctx_inc(b, "alice", 3)
  b = ctx_inc(b, "bob", 7)
  // a has alice=5, b has alice=3 and bob=7; neither dominates the other.
  assert_false(CausalContext::dominates(a, b))
  assert_false(CausalContext::dominates(b, a))
  assert_true(CausalContext::concurrent(a, b))
}

///|
test "causal_context_dominates_superset" {
  let mut a = CausalContext::new()
  let mut b = CausalContext::new()
  a = ctx_inc(a, "alice", 5)
  a = ctx_inc(a, "bob", 7)
  b = ctx_inc(b, "alice", 3)
  assert_true(CausalContext::dominates(a, b))
  assert_false(CausalContext::dominates(b, a))
}

///|
test "causal_context_next_advances_local_clock" {
  let alice = Actor::make("alice")
  let c0 = CausalContext::new()
  let (c1, d1) = c0.next(alice)
  let (c2, d2) = c1.next(alice)
  assert_eq(d1.counter(), 1)
  assert_eq(d2.counter(), 2)
  assert_eq(c2.to_map().get("alice"), Some(2))
}

///|
test "causal_context_observe_is_no_op_for_already_known_dots" {
  let alice = Actor::make("alice")
  let (c, _) = CausalContext::new().next(alice)
  let dot = Dot::new("alice", 1)
  let again = c.observe(dot)
  assert_true(CausalContext::equal(c, again))
}

///|
test "causal_context_meet_takes_per_actor_min" {
  let mut a = CausalContext::new()
  let mut b = CausalContext::new()
  a = ctx_inc(a, "alice", 5)
  a = ctx_inc(a, "bob", 7)
  b = ctx_inc(b, "alice", 3)
  let m = CausalContext::meet(a, b)
  let mm = m.to_map()
  assert_eq(mm.get("alice"), Some(3))
  // bob was only in a, so it does not appear in the meet.
  assert_eq(mm.get("bob"), None)
}

///|
fn ctx_inc(c : CausalContext, actor : String, counter : Int) -> CausalContext {
  c.observe(Dot::new(actor, counter))
}
