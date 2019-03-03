module [
    KdPoint,
    KdTree,
    build,
    nearestNeighbor,
    kNearest,
    rangeQuery,
]

## A 2D spatial point with an associated entity identifier
KdPoint : {
    id : U64,
    x : F64,
    y : F64,
}

## A node in the 2D spatial tree
KdTree : [
    Empty,
    Node {
        point : KdPoint,
        axis : U8,
        left : KdTree,
        right : KdTree,
    },
]

## Build a balanced 2D KdTree from a list of points
build : List KdPoint -> KdTree
build = \points ->
    buildWithDepth points 0

buildWithDepth : List KdPoint, U64 -> KdTree
buildWithDepth = \points, depth ->
    count = List.len points
    if count == 0 then
        Empty
    else if count == 1 then
        when List.first points is
            Ok pt ->
                axis = Num.to_u8 (depth % 2)
                Node { point: pt, axis, left: Empty, right: Empty }

            Err _ -> Empty
    else
        axis = Num.to_u8 (depth % 2)
        sorted = sortByAxis points axis
        mid = count // 2

        when List.get sorted mid is
            Ok medianPt ->
                leftPts = List.sublist sorted { start: 0, len: mid }
                rightPts = List.sublist sorted { start: mid + 1, len: count - (mid + 1) }

                leftTree = buildWithDepth leftPts (depth + 1)
                rightTree = buildWithDepth rightPts (depth + 1)

                Node {
                    point: medianPt,
                    axis,
                    left: leftTree,
                    right: rightTree,
                }

            Err _ -> Empty

sortByAxis : List KdPoint, U8 -> List KdPoint
sortByAxis = \points, axis ->
    List.sort_with points \p1, p2 ->
        val1 = if axis == 0 then p1.x else p1.y
        val2 = if axis == 0 then p2.x else p2.y
        if val1 < val2 then
            LT
        else if val1 > val2 then
            GT
        else
            EQ

distanceSq : KdPoint, F64, F64 -> F64
distanceSq = \p, qx, qy ->
    dx = p.x - qx
    dy = p.y - qy
    dx * dx + dy * dy

## Find the single nearest neighbor to a query coordinate (qx, qy)
nearestNeighbor : KdTree, F64, F64 -> Result KdPoint [TreeIsEmpty]
nearestNeighbor = \tree, qx, qy ->
    searchNearest tree qx qy (Err TreeIsEmpty) 1.0e15
    |> .bestPoint

searchNearest : KdTree, F64, F64, Result KdPoint [TreeIsEmpty], F64 -> { bestPoint : Result KdPoint [TreeIsEmpty], bestDistSq : F64 }
searchNearest = \tree, qx, qy, currentBest, currentDistSq ->
    when tree is
        Empty -> { bestPoint: currentBest, bestDistSq: currentDistSq }
        Node { point, axis, left, right } ->
            d2 = distanceSq point qx qy
            (newBest, newDistSq) =
                if d2 < currentDistSq then
                    (Ok point, d2)
                else
                    (currentBest, currentDistSq)

            coordVal = if axis == 0 then point.x else point.y
            queryVal = if axis == 0 then qx else qy
            diff = queryVal - coordVal

            (firstBranch, secondBranch) =
                if diff < 0.0 then
                    (left, right)
                else
                    (right, left)

            firstResult = searchNearest firstBranch qx qy newBest newDistSq

            # Check if second branch can contain a closer point
            if (diff * diff) < firstResult.bestDistSq then
                searchNearest secondBranch qx qy firstResult.bestPoint firstResult.bestDistSq
            else
                firstResult

## Find all points inside a rectangular bounding box
rangeQuery : KdTree, F64, F64, F64, F64 -> List KdPoint
rangeQuery = \tree, minX, minY, maxX, maxY ->
    searchRange tree minX minY maxX maxY []

searchRange : KdTree, F64, F64, F64, F64, List KdPoint -> List KdPoint
searchRange = \tree, minX, minY, maxX, maxY, acc ->
    when tree is
        Empty -> acc
        Node { point, axis, left, right } ->
            inX = point.x >= minX && point.x <= maxX
            inY = point.y >= minY && point.y <= maxY
            newAcc = if inX && inY then List.append acc point else acc

            splitCoord = if axis == 0 then point.x else point.y
            (minBound, maxBound) = if axis == 0 then (minX, maxX) else (minY, maxY)

            withLeft =
                if minBound <= splitCoord then
                    searchRange left minX minY maxX maxY newAcc
                else
                    newAcc

            if maxBound >= splitCoord then
                searchRange right minX minY maxX maxY withLeft
            else
                withLeft

## Find the k nearest points to query coordinate (qx, qy)
kNearest : KdTree, F64, F64, U64 -> List KdPoint
kNearest = \tree, qx, qy, k ->
    allPoints = collectPoints tree []
    sorted = List.sort_with allPoints \p1, p2 ->
        d1 = distanceSq p1 qx qy
        d2 = distanceSq p2 qx qy
        if d1 < d2 then LT else if d1 > d2 then GT else EQ
    List.take_first sorted k

collectPoints : KdTree, List KdPoint -> List KdPoint
collectPoints = \tree, acc ->
    when tree is
        Empty -> acc
        Node { point, left, right } ->
            withPt = List.append acc point
            withL = collectPoints left withPt
            collectPoints right withL

expect
    emptyTree = build []
    when nearestNeighbor emptyTree 0.0 0.0 is
        Err TreeIsEmpty -> Bool.true
        Ok _ -> Bool.false

expect
    p1 = { id: 1, x: 2.0, y: 3.0 }
    p2 = { id: 2, x: 5.0, y: 4.0 }
    p3 = { id: 3, x: 9.0, y: 6.0 }
    p4 = { id: 4, x: 4.0, y: 7.0 }
    p5 = { id: 5, x: 8.0, y: 1.0 }
    p6 = { id: 6, x: 7.0, y: 2.0 }

    tree = build [p1, p2, p3, p4, p5, p6]

    # Query near (9.2, 5.8) should find point 3 (9.0, 6.0)
    when nearestNeighbor tree 9.2 5.8 is
        Ok found -> found.id == 3
        Err _ -> Bool.false

expect
    p1 = { id: 1, x: 10.0, y: 10.0 }
    p2 = { id: 2, x: 20.0, y: 20.0 }
    p3 = { id: 3, x: 50.0, y: 50.0 }
    tree = build [p1, p2, p3]

    results = rangeQuery tree 5.0 5.0 25.0 25.0
    List.len results == 2

expect
    p1 = { id: 1, x: 1.0, y: 1.0 }
    p2 = { id: 2, x: 2.0, y: 2.0 }
    p3 = { id: 3, x: 10.0, y: 10.0 }
    tree = build [p1, p2, p3]

    top2 = kNearest tree 0.0 0.0 2
    List.len top2 == 2
