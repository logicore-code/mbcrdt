# Distributed Tag Store

`ORSet` powers a simple distributed tag store. Each replica can add or
remove tags; concurrent adds are preserved (observed-remove semantics),
while a remove that has been observed by all replicas wins.

The example shows the classic "two-replica tag cloud" pattern: alice and
bob each maintain a local `ORSet` of tags, periodically merging with
each other. Adding the same tag from both replicas converges to one
entry; adding different tags yields the union; removing a tag on one
replica and concurrently adding it on the other keeps the add.