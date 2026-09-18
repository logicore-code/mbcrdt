# Collaborative Counter

This example shows how to wire a `PNCounter` into a small event log that
replicates between two replicas. Two processes receive local increments
and decrements; every event is `merge`d into the shared state, so the
two replicas always agree on the total even when disconnected.

The code is intentionally tiny: no I/O, no async, no networking. The
expected use is to wrap the events in a transport (WebSocket, HTTP, a
message queue, etc.) and feed them into the `PNCounter::inc` / `dec`
methods. See `main.mbt` for the wired-up version.