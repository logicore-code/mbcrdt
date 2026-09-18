// mbcrdt.mbt
//
// Top-level facade for the mbcrdt library. This file re-exports every
// public type and function so that downstream callers can write:
//
//   use @mbcrdt.{GCounter, Actor, PNCounter}
//
// without having to remember the per-module split. The implementations
// themselves live in counter.mbt, set.mbt, dot.mbt, or_set.mbt,
// register.mbt, map.mbt, and rga.mbt; this file is purely a barrel
// that makes the public surface visible at a glance.

// -- counter layer ---------------------------------------------------------

///|
pub fn actor(s : String) -> Actor {
  Actor::make(s)
}

///|
pub fn new_gcounter() -> GCounter {
  GCounter::new()
}

///|
pub fn new_pncounter() -> PNCounter {
  PNCounter::new()
}

// -- set layer -------------------------------------------------------------

///|
pub fn[T : Eq + Hash] new_gset() -> GSet[T] {
  GSet::new()
}

///|
pub fn[T : Eq + Hash] new_two_pset() -> TwoPSet[T] {
  TwoPSet::new()
}

///|
pub fn[T : Eq + Hash] new_or_set() -> ORSet[T] {
  ORSet::new()
}

// -- register / map layer --------------------------------------------------

///|
pub fn[T] new_lww_register(init : T, who : Actor) -> LWWRegister[T] {
  LWWRegister::new(init, who)
}

///|
pub fn[V] new_lww_map() -> LWWMap[V] {
  LWWMap::new()
}

// -- rga -------------------------------------------------------------------

///|
pub fn new_rga() -> RGA {
  RGA::new()
}

///|
/// Version-vector / causal-context constructors exposed for callers that
/// want to drive deltas around without going through `ORSet` or `RGA`.
pub fn new_causal_context() -> CausalContext {
  CausalContext::new()
}