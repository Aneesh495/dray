module [
    PathResult,
    shortestPath,
    distanceVector,
    bidirectionalSearch,
]

import Graph exposing [Graph, neighbors, reverseNeighbors, nodeCount]
import PriorityQueue exposing [PriorityQueue, empty, insert, popMin, isEmpty]

PathResult : {
    distance : F64,
    path : List U64,
}

infinity : F64
infinity = 1.0e15

## Single-source Dijkstra computing shortest path to target
shortestPath : Graph, U64, U64 -> Result PathResult [NoPathFound]
shortestPath = \graph, source, target ->
    totalNodes = nodeCount graph
    if source >= totalNodes || target >= totalNodes then
        Err NoPathFound
    else if source == target then
        Ok { distance: 0.0, path: [source] }
    else
        distInit = List.repeat infinity totalNodes
        distWithSource = List.set distInit source 0.0
        parentInit = List.repeat source totalNodes

        pq0 = insert source 0.0 (empty {})

        searchResult = dijkstraLoop graph target pq0 distWithSource parentInit

        when searchResult is
            Ok { finalDist, finalParents } ->
                when List.get finalDist target is
                    Ok d ->
                        if d >= infinity / 2.0 then
                            Err NoPathFound
                        else
                            reconstructed = reconstructPath finalParents source target []
                            Ok { distance: d, path: reconstructed }

                    Err _ ->
                        Err NoPathFound

            Err err -> Err err

dijkstraLoop : Graph, U64, PriorityQueue U64, List F64, List U64 -> Result { finalDist : List F64, finalParents : List U64 } [NoPathFound]
dijkstraLoop = \graph, target, pq, dists, parents ->
    when popMin pq is
        Ok { item, queue: nextPq } ->
            u = item.value
            currentCost = item.priority

            when List.get dists u is
                Ok bestKnown ->
                    if currentCost > bestKnown then
                        # Stale queue item, skip
                        dijkstraLoop graph target nextPq dists parents
                    else if u == target then
                        # Target reached with optimal distance
                        Ok { finalDist: dists, finalParents: parents }
                    else
                        # Relax outgoing edges
                        edgeList = neighbors graph u
                        updated = List.walk edgeList { q: nextPq, d: dists, p: parents } \acc, edge ->
                            v = edge.target
                            newCost = currentCost + edge.weight
                            when List.get acc.d v is
                                Ok oldCost ->
                                    if newCost < oldCost then
                                        newDists = List.set acc.d v newCost
                                        newParents = List.set acc.p v u
                                        newQueue = insert v newCost acc.q
                                        { q: newQueue, d: newDists, p: newParents }
                                    else
                                        acc

                                Err _ -> acc

                        dijkstraLoop graph target updated.q updated.d updated.p

                Err _ ->
                    dijkstraLoop graph target nextPq dists parents

        Err _ ->
            # Priority queue exhausted
            Ok { finalDist: dists, finalParents: parents }

## Compute distances from source to all nodes in the graph
distanceVector : Graph, U64 -> List F64
distanceVector = \graph, source ->
    totalNodes = nodeCount graph
    if source >= totalNodes then
        List.repeat infinity totalNodes
    else
        distInit = List.repeat infinity totalNodes
        distWithSource = List.set distInit source 0.0
        parentInit = List.repeat source totalNodes
        pq0 = insert source 0.0 (empty {})

        when dijkstraLoop graph (totalNodes + 1) pq0 distWithSource parentInit is
            Ok { finalDist } -> finalDist
            Err _ -> List.repeat infinity totalNodes

## Reconstruct path from predecessors list
reconstructPath : List U64, U64, U64, List U64 -> List U64
reconstructPath = \parents, source, current, acc ->
    withCurrent = List.prepend acc current
    if current == source then
        withCurrent
    else
        when List.get parents current is
            Ok prev ->
                if prev == current then
                    withCurrent
                else
                    reconstructPath parents source prev withCurrent

            Err _ -> withCurrent

## Bi-directional Dijkstra search meeting from source and target
bidirectionalSearch : Graph, U64, U64 -> Result F64 [NoPathFound]
bidirectionalSearch = \graph, source, target ->
    totalNodes = nodeCount graph
    if source >= totalNodes || target >= totalNodes then
        Err NoPathFound
    else if source == target then
        Ok 0.0
    else
        fwdDist0 = List.repeat infinity totalNodes |> (\l -> List.set l source 0.0)
        revDist0 = List.repeat infinity totalNodes |> (\l -> List.set l target 0.0)

        fwdPq0 = insert source 0.0 (empty {})
        revPq0 = insert target 0.0 (empty {})

        stepBiSearch graph fwdPq0 revPq0 fwdDist0 revDist0 infinity

stepBiSearch : Graph, PriorityQueue U64, PriorityQueue U64, List F64, List F64, F64 -> Result F64 [NoPathFound]
stepBiSearch = \graph, fwdPq, revPq, fwdDist, revDist, bestMu ->
    if isEmpty fwdPq && isEmpty revPq then
        if bestMu < infinity / 2.0 then
            Ok bestMu
        else
            Err NoPathFound
    else
        # Expand forward step
        (fwdNextPq, fwdNextDist, muFwd) =
            when popMin fwdPq is
                Ok { item, queue } ->
                    u = item.value
                    c = item.priority
                    when List.get fwdDist u is
                        Ok d ->
                            if c > d then
                                (queue, fwdDist, bestMu)
                            else
                                relaxFwd graph u c queue fwdDist revDist bestMu

                        Err _ -> (queue, fwdDist, bestMu)

                Err _ -> (fwdPq, fwdDist, bestMu)

        # Expand backward step
        (revNextPq, revNextDist, muFinal) =
            when popMin revPq is
                Ok { item, queue } ->
                    v = item.value
                    c = item.priority
                    when List.get revDist v is
                        Ok d ->
                            if c > d then
                                (queue, revDist, muFwd)
                            else
                                relaxRev graph v c queue fwdNextDist revDist muFwd

                        Err _ -> (queue, revDist, muFwd)

                Err _ -> (revPq, revDist, muFwd)

        # Check termination condition: if min keys sum exceeds bestMu, stop
        fwdMin = when PriorityQueue.peekMin fwdNextPq is
            Ok it -> it.priority
            Err _ -> infinity

        revMin = when PriorityQueue.peekMin revNextPq is
            Ok it -> it.priority
            Err _ -> infinity

        if fwdMin + revMin >= muFinal then
            if muFinal < infinity / 2.0 then
                Ok muFinal
            else
                Err NoPathFound
        else
            stepBiSearch graph fwdNextPq revNextPq fwdNextDist revNextDist muFinal

relaxFwd : Graph, U64, F64, PriorityQueue U64, List F64, List F64, F64 -> (PriorityQueue U64, List F64, F64)
relaxFwd = \graph, u, costU, pq, fwdDist, revDist, currentMu ->
    edges = neighbors graph u
    List.walk edges (pq, fwdDist, currentMu) \(accPq, accDist, accMu), edge ->
        v = edge.target
        newCost = costU + edge.weight
        oldCost = when List.get accDist v is
            Ok oc -> oc
            Err _ -> infinity

        if newCost < oldCost then
            newDist = List.set accDist v newCost
            newPq = insert v newCost accPq
            # Check connection with reverse frontier
            revCost = when List.get revDist v is
                Ok rc -> rc
                Err _ -> infinity
            candidate = newCost + revCost
            updatedMu = if candidate < accMu then candidate else accMu
            (newPq, newDist, updatedMu)
        else
            (accPq, accDist, accMu)

relaxRev : Graph, U64, F64, PriorityQueue U64, List F64, List F64, F64 -> (PriorityQueue U64, List F64, F64)
relaxRev = \graph, v, costV, pq, fwdDist, revDist, currentMu ->
    edges = reverseNeighbors graph v
    List.walk edges (pq, revDist, currentMu) \(accPq, accDist, accMu), edge ->
        u = edge.target
        newCost = costV + edge.weight
        oldCost = when List.get accDist u is
            Ok oc -> oc
            Err _ -> infinity

        if newCost < oldCost then
            newDist = List.set accDist u newCost
            newPq = insert u newCost accPq
            # Check connection with forward frontier
            fwdCost = when List.get fwdDist u is
                Ok fc -> fc
                Err _ -> infinity
            candidate = fwdCost + newCost
            updatedMu = if candidate < accMu then candidate else accMu
            (newPq, newDist, updatedMu)
        else
            (accPq, accDist, accMu)

expect
    # Triangle graph: 0 -> 1 (weight 5), 1 -> 2 (weight 3), 0 -> 2 (weight 10)
    # Shortest path 0 -> 2 should be 0 -> 1 -> 2 with cost 8.0
    g =
        Graph.withNodes 3
        |> (\g0 -> Graph.addEdge g0 0 1 5.0 5.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 1 2 3.0 3.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 0 2 10.0 10.0 Bool.false 0)

    when shortestPath g 0 2 is
        Ok { distance, path } ->
            approxOk = Num.is_approx_eq distance 8.0 { atol: 0.001 }
            pathOk = path == [0, 1, 2]
            approxOk && pathOk

        Err _ -> Bool.false

expect
    # Bi-directional search matches single-source Dijkstra
    g =
        Graph.withNodes 4
        |> (\g0 -> Graph.addEdge g0 0 1 2.0 2.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 1 2 4.0 4.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 2 3 1.0 1.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 0 3 10.0 10.0 Bool.false 0)

    when bidirectionalSearch g 0 3 is
        Ok d -> Num.is_approx_eq d 7.0 { atol: 0.001 }
        Err _ -> Bool.false
