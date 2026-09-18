# mbcrdt

A pure-MoonBit **Conflict-free Replicated Data Type** library. CRDTs are
data structures that allow multiple replicas of a state to converge
without coordination; the same library code runs on every replica, and
the only thing the replicas need to agree on is the eventual delivery of
updates. They power offline-first apps, collaborative editors,
distributed databases, AI agent coordination layers, and anywhere else
you need a shared mutable state across unreliable networks.

This crate is part of the **2026 MoonBit 9-month Hackathon** submission
and targets the MoonBit `wasm`, `wasm-gc`, `js`, and `native` backends
with **zero dependencies** beyond the MoonBit core prelude.

## Features

| CRDT          | Use case                                               |
|---------------|--------------------------------------------------------|
| `GCounter`    | Distributed like / view counters                       |
| `PNCounter`   | Distributed scoreboards, fan-out counters              |
| `GSet`        | Add-only membership / presence lists                   |
| `TwoPSet`     | Hard tombstones, e.g. banned users                     |
| `ORSet`       | Tag clouds, presence, feature flags                    |
| `LWWRegister` | Single-value "last-write-wins" cells                    |
| `LWWMap`      | Key-value store with per-key LWW semantics             |
| `RGA`         | Replicated growable array, collaborative text editing  |
| `CausalContext` | Version vector / causal context for delta propagation |
| `Dot`         | `(actor, counter)` event identifier                    |

The library is **state-based** (CvRDT) for everything except the `RGA`
which uses the standard op-based / interleaving algorithm. Every state
CRDT comes with a provably commutative, associative, and idempotent
merge operation so that updates can be applied in any order and any
number of times.

## Quick start

Add `mbcrdt` to your `moon.mod`:

```toml
import {
  "logicore-code/mbcrdt",
}
```

Then:

```mbt
let alice = Actor::make("alice")
let bob = Actor::make("bob")

// Two replicas start with their own counter and synchronise later.
let mut a = PNCounter::new()
let mut b = PNCounter::new()
a = PNCounter::inc(a, alice, delta=7)
b = PNCounter::inc(b, bob, delta=5)
a = PNCounter::merge(a, b)
b = PNCounter::merge(b, a)

assert_eq(a.value(), 12)
assert_eq(b.value(), 12)
```

A working two-replica counter demo lives in
[`examples/collaborative_counter`](./examples/collaborative_counter),
two-replica collaborative text in
[`examples/collaborative_text`](./examples/collaborative_text), and a
distributed tag store in
[`examples/distributed_tags`](./examples/distributed_tags).

## Architecture

```
mbcrdt/
├── counter.mbt        # GCounter, PNCounter
├── set.mbt            # GSet, TwoPSet
├── dot.mbt            # Dot, CausalContext (version vector)
├── or_set.mbt         # ORSet (uses Dot/CausalContext)
├── register.mbt       # LWWRegister, LWWTime
├── map.mbt            # LWWMap
├── rga.mbt            # RGA (replicated growable array)
├── *_test.mbt         # Black-box tests
├── *_wbtest.mbt       # White-box tests (need package internals)
└── examples/
    ├── collaborative_counter/  # `moon run` this to see convergence
    ├── collaborative_text/     # Two-replica text editor
    └── distributed_tags/       # ORSet tag-cloud
```

All CRDTs are **immutable values**: every mutator returns a new snapshot
that does not share structure with the previous one. This means that two
replicas can independently evolve their state and any updates that
arrive out of order will simply replace the local copy with the merged
result.

## Tests and CI

```bash
moon test           # run every test in this package
moon info           # regenerate .mbti interfaces
moon fmt --check    # ensure formatting is clean
```

The GitHub Actions workflow in
[`.github/workflows/ci.yml`](./.github/workflows/ci.yml) runs `moon check`,
`moon test`, `moon fmt --check`, and `moon info` on every push so that
PRs cannot land broken builds.

## Building

```bash
moon build --target wasm-gc   # smallest wasm output for the browser
moon build --target wasm      # classic wasm
moon build --target js        # for use from Node.js / the browser
moon build --target native    # native binary via LLVM
```

## License

Apache 2.0. See [LICENSE](./LICENSE).

## References

- Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
  _A comprehensive study of Convergent and Commutative Replicated Data
  Types._ INRIA TR 7506.
- Baquero, C., Almeida, P., Cunha, A. (2024). _The Algebra of CRDTs._
- Letia, M., Preguiça, N., Shapiro, M. (2009). _Consistency without
  ordering: The CRDT whiteboard case study._ INRIA TR 7320.
- Bieniusa, A., Zawirski, M., Preguiça, N., Shapiro, M., Baquero, C.,
  Balegas, V., Duarte, S. (2012). _An optimized conflict-free replicated
  set._
- Almeida, P., Shoker, A., Baquero, C. (2018). _Delta State Replicated
  Data Types._ JPDC.