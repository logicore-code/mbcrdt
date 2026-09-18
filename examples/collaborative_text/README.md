# Collaborative Text Editor

This example builds a tiny two-replica collaborative text editor on top
of the `RGA` CRDT. Two replicas (alice and bob) start with a shared
seed string, then make concurrent edits and synchronise; the result
shows that both replicas converge on the same final text.

The model is deliberately minimal:
- Each replica keeps a local `RGA`.
- Local edits are applied immediately.
- A "sync" step merges the two RGAs in both directions.

In a real system you would also propagate the per-edit `Dot` events
over a transport so that the receiver can observe causally-ordered
operations; the merge here takes the simpler "full state sync"
shortcut.