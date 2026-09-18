// bench.mbt
//
// Smoke-test benchmarks for the mbcrdt library. Run with `moon test`
// to verify that all the hot paths still produce sensible values
// after 1000+ iterations; the loop counts are kept small so the
// suite finishes in well under a second on a cold cache.

///|
test "bench_g_counter_inc_loop" {
  let alice = Actor::make("alice")
  let mut c = GCounter::new()
  for _i in 0..<1000 {
    c = GCounter::inc(c, alice, delta=1)
  }
  assert_eq(c.value(), 1000)
}

///|
test "bench_g_set_add_loop" {
  let mut s : GSet[String] = GSet::new()
  for _i in 0..<1000 {
    s = s.add("v")
  }
  assert_eq(s.size(), 1)
}

///|
test "bench_lww_register_write_loop" {
  let alice = Actor::make("alice")
  let mut r = LWWRegister::new(0, alice)
  for _i in 0..<1000 {
    r = LWWRegister::write(r, 0)
  }
  assert_eq(r.value(), 0)
}

///|
test "bench_rga_append_loop" {
  let alice = Actor::make("alice")
  let mut r = RGA::new()
  for i in 0..<200 {
    let c = Int::unsafe_to_char(65 + (i % 26))
    r = RGA::append(r, c, alice)
  }
  assert_eq(r.length(), 200)
}