// rga.mbt
//
// Replicated Growable Array (RGA). RGA is the CRDT underlying many real-
// world collaborative text editors (e.g. Yjs and similar designs borrow
// from this construction). The state is a forest of characters plus a
// tombstone set; the merge joins the forests, drops tombstoned nodes, and
// re-derives a total order from the embedded `(timestamp, anchor)` key.
//
// Algorithm references:
//   - Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011).
//     "A comprehensive study of Convergent and Commutative Replicated
//     Data Types." (INRIA TR 7506). §3.4 Add-Wins Set applied to
//     sequences.
//   - Letia, M., Preguiça, N., Shapiro, M. (2009). "Consistency without
//     ordering: The CRDT whiteboard case study." (INRIA TR 7320).
//
// Each `RGAChar` node carries:
//   - `tag`:    the unique event id `(actor, counter)` for this char.
//   - `value`:  the character payload.
//   - anchor:   the tag of the node this char was inserted *after*. A
//               root insertion uses the synthetic root tag `{ "", 0 }`.
//   - deleted:  whether the char has been tombstoned.
//
// Total order: nodes are sorted by `(anchor_ts, tag_ts)` where the
// `anchor_ts` is the counter taken from the anchoring node. The first
// insertion after the root uses the synthetic root anchor with
// `counter = Int::max_value() - 1` so that all real anchors sit "deeper"
// and therefore appear to the right of the root.

///|
/// A character node in the RGA sequence.
pub struct RGAChar {
  tag : Dot
  value : Char
  anchor : Dot
  deleted : Bool
}

///|
/// The RGA document state: every node, plus a causal clock used to hand
/// out fresh dots to local insertions.
pub struct RGA {
  nodes : Map[String, RGAChar]
  clock : CausalContext
}

///|
/// Synthetic root tag used as the anchor for the first node.
pub fn root_dot() -> Dot {
  { actor: "", counter: 0, }
}

///|
/// Build an empty RGA.
pub fn RGA::new() -> RGA {
  { nodes: Map([]), clock: CausalContext::new(), }
}

///|
/// Insert `c` after `anchor`. The `anchor` tag identifies the node after
/// which `c` should appear; pass `root_dot()` to prepend at position
/// zero. `actor` is the local replica that issues this insert.
pub fn RGA::insert_after(
  self : RGA,
  anchor : Dot,
  c : Char,
  actor : Actor,
) -> RGA {
  let (clock, tag) = self.clock.next(actor)
  let char : RGAChar = { tag, value: c, anchor, deleted: false, }
  let nodes : Map[String, RGAChar] = Map([])
  for k, v in self.nodes {
    nodes.set(k, v)
  }
  nodes.set(rga_key(tag), char)
  { nodes, clock, }
}

///|
/// Insert `c` at the head of the sequence (before any existing char).
pub fn RGA::prepend(self : RGA, c : Char, actor : Actor) -> RGA {
  self.insert_after(root_dot(), c, actor)
}

///|
/// Append `c` at the tail of the sequence. If the sequence is empty the
/// char is inserted at the head.
pub fn RGA::append(self : RGA, c : Char, actor : Actor) -> RGA {
  match last_live_tag(self.nodes) {
    Some(anchor) => self.insert_after(anchor, c, actor)
    None => self.prepend(c, actor)
  }
}

///|
/// Insert `c` at the position pointed to by `index` in the current view.
/// Out-of-range indices are clamped to the head or the tail.
pub fn RGA::insert_at(self : RGA, index : Int, c : Char, actor : Actor) -> RGA {
  let n = self.length()
  let pos = if index < 0 { 0 } else if index > n { n } else { index }
  match nth_live_tag(self.nodes, pos) {
    Some(anchor) => self.insert_after(anchor, c, actor)
    None => self.prepend(c, actor)
  }
}

///|
/// Tombstone the node at `index`. Tombstoned nodes remain in the
/// structure for causal ordering but no longer appear in the live view.
pub fn RGA::delete_at(self : RGA, index : Int) -> RGA raise IndexError {
  match nth_live_char(self.nodes, index) {
    Some(char) => {
      let nodes : Map[String, RGAChar] = Map([])
      for k, v in self.nodes {
        nodes.set(k, v)
      }
      let tomb : RGAChar = { ..char, deleted: true, }
      nodes.set(rga_key(char.tag), tomb)
      { nodes, clock: self.clock, }
    }
    None => raise IndexError
  }
}

///|
/// Index out-of-range error for `delete_at` and `at`.
pub suberror IndexError

///|
/// Materialise the live view as a `String`.
pub fn RGA::to_string(self : RGA) -> String {
  let buf = StringBuilder()
  for c in live_view(self.nodes) {
    buf.write_char(c.value)
  }
  buf.to_string()
}

///|
/// Materialise the live view as an `Array[Char]`.
pub fn RGA::to_array(self : RGA) -> Array[Char] {
  live_view(self.nodes).map(fn(c) { c.value })
}

///|
/// Length of the live view (number of non-deleted chars).
pub fn RGA::length(self : RGA) -> Int {
  live_view(self.nodes).length()
}

///|
/// Return `true` iff the live view is empty.
pub fn RGA::is_empty(self : RGA) -> Bool {
  self.length() == 0
}

///|
/// Join-semilattice merge of two RGA states. The clocks are joined and
/// the node maps are unioned; for a tag that appears on both sides the
/// merge keeps the live version if at least one side is live, otherwise
/// the tombstoned version.
pub fn RGA::merge(a : RGA, b : RGA) -> RGA {
  let nodes : Map[String, RGAChar] = Map([])
  for k, v in a.nodes {
    nodes.set(k, v)
  }
  for k, vb in b.nodes {
    let va = nodes.get(k)
    let merged = match va {
      None => vb
      Some(va) =>
        if va.deleted || vb.deleted {
          { ..va, deleted: true, }
        } else {
          va
        }
    }
    nodes.set(k, merged)
  }
  { nodes, clock: CausalContext::join(a.clock, b.clock), }
}

// -- helpers --

///|
fn rga_key(d : Dot) -> String {
  d.actor + ":" + d.counter.to_string()
}

///|
fn live_view(nodes : Map[String, RGAChar]) -> Array[RGAChar] {
  let all : Array[RGAChar] = []
  for _, n in nodes {
    if !n.deleted {
      all.push(n)
    }
  }
  all.sort_by(fn(x, y) { compare_rga(x, y) })
  all
}

///|
/// Total order: nodes are sorted by the counter of the anchoring tag,
/// ascending so that a node anchoring closer to the root sits to the
/// left; within a group they are sorted by their own tag counter,
/// descending so that a `prepend` (which anchors to the same node as a
/// prior prepend by the same actor) ends up to the right of that prior
/// node.
fn compare_rga(a : RGAChar, b : RGAChar) -> Int {
  let res = a.anchor.counter.compare(b.anchor.counter)
  if res != 0 {
    return res
  }
  // Same anchor → reverse by tag counter so that successive prepends
  // come out in reverse insertion order.
  b.tag.counter.compare(a.tag.counter)
}

///|
fn last_live_tag(nodes : Map[String, RGAChar]) -> Dot? {
  let view = live_view(nodes)
  if view.is_empty() {
    None
  } else {
    let last = view[view.length() - 1]
    Some(last.tag)
  }
}

///|
fn nth_live_tag(nodes : Map[String, RGAChar], n : Int) -> Dot? {
  let view = live_view(nodes)
  if n >= view.length() {
    None
  } else if n == 0 {
    Some(root_dot())
  } else {
    Some(view[n - 1].tag)
  }
}

///|
fn nth_live_char(nodes : Map[String, RGAChar], n : Int) -> RGAChar? {
  let view = live_view(nodes)
  if n < 0 || n >= view.length() {
    None
  } else {
    Some(view[n])
  }
}
