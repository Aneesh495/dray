module [
    ContractionHierarchy,
    contractGraph,
    chQuery,
    unpackPath,
]

import Graph exposing [Graph, neighbors, reverseNeighbors, nodeCount, addEdge, findEdgeWeight]
import PriorityQueue exposing [PriorityQueue, empty, insert, popMin, isEmpty]

ContractionHierarchy : {
    chGraph : Graph,
    nodeRanks : List U64,
}

infinity : F64
infinity = 1.0e15

## Contract all nodes in a road network graph and produce a Contraction Hierarchy
contractGraph : Graph -> ContractionHierarchy
contractGraph = \initialGraph ->
    n = nodeCount initialGraph
    # Simple initial ordering by node index (or degree heuristic)
    contractNodesSequentially initialGraph 0 n []

contractNodesSequentially : Graph, U64, U64, List U64 -> ContractionHierarchy
contractNodesSequentially = \g, currentIdx, total, ranksAcc ->
    if currentIdx >= total then
        { chGraph: g, nodeRanks: ranksAcc }
    else
        # Contract node currentIdx: find all incoming and outgoing edges
        inEdges = reverseNeighbors g currentIdx
        outEdges = neighbors g currentIdx

        # For every pair (u -> currentIdx) and (currentIdx -> w), check if shortcut needed
        withShortcuts = List.walk inEdges g \gAcc, inEdge ->
            u = inEdge.target
            if u == currentIdx then
                gAcc
            else
                List.walk outEdges gAcc \innerG, outEdge ->
                    w = outEdge.target
                    if w == currentIdx || w == u then
                        innerG
                    else
                        pathViaNode = inEdge.weight + outEdge.weight
                        # Check if a direct edge or alternate path already exists with weight <= pathViaNode
                        needsShortcut =
                            when findEdgeWeight innerG u w is
                                Ok directWeight -> pathViaNode < directWeight
                                Err EdgeNotFound -> Bool.true

                        if needsShortcut then
                            distTotal = inEdge.distance + outEdge.distance
                            addEdge innerG u w pathViaNode distTotal Bool.true currentIdx
                        else
                            innerG

        contractNodesSequentially withShortcuts (currentIdx + 1) total (List.append ranksAcc currentIdx)

## Perform a bidirectional upward search on the Contraction Hierarchy
chQuery : ContractionHierarchy, U64, U64 -> Result { distance : F64, meetingNode : U64 } [NoPathFound]
chQuery = \ch, source, target ->
    total = nodeCount ch.chGraph
    if source >= total || target >= total then
        Err NoPathFound
    else if source == target then
        Ok { distance: 0.0, meetingNode: source }
    else
        fwdDist0 = List.repeat infinity total |> (\l -> List.set l source 0.0)
        revDist0 = List.repeat infinity total |> (\l -> List.set l target 0.0)

        fwdPq0 = insert source 0.0 (empty {})
        revPq0 = insert target 0.0 (empty {})

        stepChQuery ch fwdPq0 revPq0 fwdDist0 revDist0 infinity source

stepChQuery : ContractionHierarchy, PriorityQueue U64, PriorityQueue U64, List F64, List F64, F64, U64 -> Result { distance : F64, meetingNode : U64 } [NoPathFound]
stepChQuery = \ch, fwdPq, revPq, fwdDist, revDist, bestDist, bestMeeting ->
    if isEmpty fwdPq && isEmpty revPq then
        if bestDist < infinity / 2.0 then
            Ok { distance: bestDist, meetingNode: bestMeeting }
        else
            Err NoPathFound
    else
        # Expand forward upward edges
        (fwdNextPq, fwdNextDist, muFwd, meetFwd) =
            when popMin fwdPq is
                Ok { item, queue } ->
                    u = item.value
                    c = item.priority
                    when List.get fwdDist u is
                        Ok d ->
                            if c > d then
                                (queue, fwdDist, bestDist, bestMeeting)
                            else
                                relaxUpwardFwd ch u c queue fwdDist revDist bestDist bestMeeting

                        Err _ -> (queue, fwdDist, bestDist, bestMeeting)

                Err _ -> (fwdPq, fwdDist, bestDist, bestMeeting)

        # Expand backward upward edges
        (revNextPq, revNextDist, muFinal, meetFinal) =
            when popMin revPq is
                Ok { item, queue } ->
                    v = item.value
                    c = item.priority
                    when List.get revDist v is
                        Ok d ->
                            if c > d then
                                (queue, revDist, muFwd, meetFwd)
                            else
                                relaxUpwardRev ch v c queue fwdNextDist revDist muFwd meetFwd

                        Err _ -> (queue, revDist, muFwd, meetFwd)

                Err _ -> (revPq, revDist, muFwd, meetFwd)

        # Termination: if min priority in forward and reverse queues exceeds best, we have optimum
        fwdMin = when PriorityQueue.peekMin fwdNextPq is
            Ok it -> it.priority
            Err _ -> infinity

        revMin = when PriorityQueue.peekMin revNextPq is
            Ok it -> it.priority
            Err _ -> infinity

        if fwdMin >= muFinal && revMin >= muFinal then
            if muFinal < infinity / 2.0 then
                Ok { distance: muFinal, meetingNode: meetFinal }
            else
                Err NoPathFound
        else
            stepChQuery ch fwdNextPq revNextPq fwdNextDist revNextDist muFinal meetFinal

relaxUpwardFwd : ContractionHierarchy, U64, F64, PriorityQueue U64, List F64, List F64, F64, U64 -> (PriorityQueue U64, List F64, F64, U64)
relaxUpwardFwd = \ch, u, costU, pq, fwdDist, revDist, currentBest, currentMeet ->
    uRank = getRank ch u
    edges = neighbors ch.chGraph u

    List.walk edges (pq, fwdDist, currentBest, currentMeet) \(accPq, accDist, accBest, accMeet), edge ->
        v = edge.target
        vRank = getRank ch v
        # Upward graph property: only relax edges to nodes with strictly higher rank
        if vRank > uRank then
            newCost = costU + edge.weight
            oldCost = when List.get accDist v is
                Ok oc -> oc
                Err _ -> infinity

            if newCost < oldCost then
                newDist = List.set accDist v newCost
                newPq = insert v newCost accPq

                revCost = when List.get revDist v is
                    Ok rc -> rc
                    Err _ -> infinity

                candidate = newCost + revCost
                if candidate < accBest then
                    (newPq, newDist, candidate, v)
                else
                    (newPq, newDist, accBest, accMeet)
            else
                (accPq, accDist, accBest, accMeet)
        else
            (accPq, accDist, accBest, accMeet)

relaxUpwardRev : ContractionHierarchy, U64, F64, PriorityQueue U64, List F64, List F64, F64, U64 -> (PriorityQueue U64, List F64, F64, U64)
relaxUpwardRev = \ch, v, costV, pq, fwdDist, revDist, currentBest, currentMeet ->
    vRank = getRank ch v
    edges = reverseNeighbors ch.chGraph v

    List.walk edges (pq, revDist, currentBest, currentMeet) \(accPq, accDist, accBest, accMeet), edge ->
        u = edge.target
        uRank = getRank ch u
        # Upward graph property: in reverse search, only relax edges from nodes with strictly higher rank
        if uRank > vRank then
            newCost = costV + edge.weight
            oldCost = when List.get accDist u is
                Ok oc -> oc
                Err _ -> infinity

            if newCost < oldCost then
                newDist = List.set accDist u newCost
                newPq = insert u newCost accPq

                fwdCost = when List.get fwdDist u is
                    Ok fc -> fc
                    Err _ -> infinity

                candidate = fwdCost + newCost
                if candidate < accBest then
                    (newPq, newDist, candidate, u)
                else
                    (newPq, newDist, accBest, accMeet)
            else
                (accPq, accDist, accBest, accMeet)
        else
            (accPq, accDist, accBest, accMeet)

getRank : ContractionHierarchy, U64 -> U64
getRank = \ch, node ->
    when List.get ch.nodeRanks node is
        Ok r -> r
        Err _ -> node

## Unpack a shortcut edge recursively to retrieve the original list of traversed nodes
unpackPath : Graph, U64, U64 -> List U64
unpackPath = \graph, u, v ->
    edges = neighbors graph u
    edgeFound = List.walk_until edges (Err EdgeNotFound) \_, edge ->
        if edge.target == v then
            Break (Ok edge)
        else
            Continue (Err EdgeNotFound)

    when edgeFound is
        Ok edge ->
            if edge.isShortcut then
                # Recursively unpack left half (u -> bypassed) and right half (bypassed -> v)
                mid = edge.bypassedNode
                leftHalf = unpackPath graph u mid
                rightHalf = unpackPath graph mid v
                # Combine avoiding duplicate middle node
                List.concat leftHalf (List.drop_first rightHalf 1)
            else
                [u, v]

        Err _ -> [u, v]

expect
    # 4-node line: 0 <-> 1 <-> 2 <-> 3
    # When node 1 is contracted, a shortcut 0 <-> 2 is formed.
    # When node 2 is contracted, a shortcut 0 <-> 3 is formed.
    g =
        Graph.withNodes 4
        |> (\g0 -> Graph.addBidirectionalEdge g0 0 1 5.0 5.0)
        |> (\g0 -> Graph.addBidirectionalEdge g0 1 2 4.0 4.0)
        |> (\g0 -> Graph.addBidirectionalEdge g0 2 3 6.0 6.0)

    ch = contractGraph g

    # Query 0 -> 3 should return exact distance 15.0
    when chQuery ch 0 3 is
        Ok { distance } ->
            Num.is_approx_eq distance 15.0 { atol: 0.001 }

        Err _ ->
            Bool.false

expect
    # Unpack shortcut test
    g =
        Graph.withNodes 3
        |> (\g0 -> Graph.addEdge g0 0 1 10.0 10.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 1 2 20.0 20.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 0 2 30.0 30.0 Bool.true 1)

    path = unpackPath g 0 2
    path == [0, 1, 2]
