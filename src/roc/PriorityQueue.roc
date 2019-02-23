module [
    PriorityQueue,
    empty,
    insert,
    popMin,
    peekMin,
    size,
    isEmpty,
]

## A priority queue item pairing an item with its numerical priority
Item a : {
    priority : F64,
    value : a,
}

## A binary min-heap backed by a flat list
PriorityQueue a : {
    heap : List (Item a),
}

## Create an empty priority queue
empty : {} -> PriorityQueue a
empty = \{} -> { heap: [] }

## Return the number of elements in the priority queue
size : PriorityQueue a -> U64
size = \pq -> List.len pq.heap

## Check if the priority queue has no elements
isEmpty : PriorityQueue a -> Bool
isEmpty = \pq -> List.is_empty pq.heap

## Look at the element with the lowest priority value without removing it
peekMin : PriorityQueue a -> Result (Item a) [QueueIsEmpty]
peekMin = \pq ->
    when List.first pq.heap is
        Ok item -> Ok item
        Err _ -> Err QueueIsEmpty

## Push a new item with associated priority into the queue
## The queue is the last argument to facilitate the pipe operator
insert : a, F64, PriorityQueue a -> PriorityQueue a
insert = \value, priority, pq ->
    newItem = { priority, value }
    appended = List.append pq.heap newItem
    newIndex = List.len appended - 1
    { heap: siftUp appended newIndex }

## Internal helper to restore min-heap invariant upwards from child to root
siftUp : List (Item a), U64 -> List (Item a)
siftUp = \items, idx ->
    if idx == 0 then
        items
    else
        parentIdx = (idx - 1) // 2
        when (List.get items idx, List.get items parentIdx) is
            (Ok current, Ok parent) ->
                if current.priority < parent.priority then
                    swapped = List.swap items idx parentIdx
                    siftUp swapped parentIdx
                else
                    items

            _ -> items

## Pop and return the element with the lowest priority value
popMin : PriorityQueue a -> Result { item : Item a, queue : PriorityQueue a } [QueueIsEmpty]
popMin = \pq ->
    count = List.len pq.heap
    if count == 0 then
        Err QueueIsEmpty
    else if count == 1 then
        when List.first pq.heap is
            Ok first ->
                Ok { item: first, queue: { heap: [] } }

            Err _ ->
                Err QueueIsEmpty
    else
        when (List.first pq.heap, List.last pq.heap) is
            (Ok root, Ok lastItem) ->
                trimmed = List.drop_at pq.heap (count - 1)
                replaced = List.set trimmed 0 lastItem
                sifted = siftDown replaced 0
                Ok { item: root, queue: { heap: sifted } }

            _ ->
                Err QueueIsEmpty

## Internal helper to restore min-heap invariant downwards from root to leaves
siftDown : List (Item a), U64 -> List (Item a)
siftDown = \items, idx ->
    total = List.len items
    leftChild = 2 * idx + 1
    rightChild = 2 * idx + 2

    smallestIdx = idx
    withLeft =
        if leftChild < total then
            when (List.get items leftChild, List.get items smallestIdx) is
                (Ok leftItem, Ok smallItem) ->
                    if leftItem.priority < smallItem.priority then leftChild else smallestIdx

                _ -> smallestIdx
        else
            smallestIdx

    withRight =
        if rightChild < total then
            when (List.get items rightChild, List.get items withLeft) is
                (Ok rightItem, Ok smallItem) ->
                    if rightItem.priority < smallItem.priority then rightChild else withLeft

                _ -> withLeft
        else
            withLeft

    if withRight != idx then
        swapped = List.swap items idx withRight
        siftDown swapped withRight
    else
        items

expect
    pq0 : PriorityQueue Str
    pq0 = empty {}
    isEmpty pq0 == Bool.true

expect
    pq1 = insert "taskA" 10.0 (empty {})
    pq2 = insert "taskB" 5.0 pq1
    pq3 = insert "taskC" 15.0 pq2
    size pq3 == 3

expect
    pq0 = insert "apple" 30.0 (empty {})
    pq1 = insert "banana" 10.0 pq0
    pq2 = insert "cherry" 20.0 pq1
    when popMin pq2 is
        Ok { item, queue } ->
            item.value == "banana" && size queue == 2

        Err _ ->
            Bool.false

expect
    pq =
        empty {}
        |> (\q -> insert "four" 40.0 q)
        |> (\q -> insert "one" 10.0 q)
        |> (\q -> insert "three" 30.0 q)
        |> (\q -> insert "two" 20.0 q)
    when popMin pq is
        Ok r1 ->
            when popMin r1.queue is
                Ok r2 ->
                    r1.item.value == "one" && r2.item.value == "two"

                Err _ -> Bool.false

        Err _ -> Bool.false
