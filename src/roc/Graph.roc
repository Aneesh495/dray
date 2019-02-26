module [
    Edge,
    Graph,
    empty,
    withNodes,
    addEdge,
    addBidirectionalEdge,
    neighbors,
    reverseNeighbors,
    nodeCount,
    edgeCount,
    findEdgeWeight,
]

## A directed edge representing a road segment or contraction shortcut
Edge : {
    target : U64,
    weight : F64,
    distance : F64,
    isShortcut : Bool,
    bypassedNode : U64,
}

## A directed road network graph stored with forward and reverse adjacency lists
Graph : {
    adj : List (List Edge),
    revAdj : List (List Edge),
}

## Create a new empty graph
empty : {} -> Graph
empty = \{} -> {
    adj: [],
    revAdj: [],
}

## Initialize a graph with a fixed number of disconnected nodes
withNodes : U64 -> Graph
withNodes = \count -> {
    adj: List.repeat [] count,
    revAdj: List.repeat [] count,
}

## Return total number of nodes in graph
nodeCount : Graph -> U64
nodeCount = \g -> List.len g.adj

## Add a directed edge from source to target
addEdge : Graph, U64, U64, F64, F64, Bool, U64 -> Graph
addEdge = \g, src, target, weight, distance, isShortcut, bypassedNode ->
    total = List.len g.adj
    if src >= total || target >= total then
        g
    else
        edgeFwd = { target, weight, distance, isShortcut, bypassedNode }
        edgeRev = { target: src, weight, distance, isShortcut, bypassedNode }

        newAdj =
            when List.get g.adj src is
                Ok curList -> List.set g.adj src (List.append curList edgeFwd)
                Err _ -> g.adj

        newRev =
            when List.get g.revAdj target is
                Ok curRev -> List.set g.revAdj target (List.append curRev edgeRev)
                Err _ -> g.revAdj

        { adj: newAdj, revAdj: newRev }

## Add a two-way edge between two nodes
addBidirectionalEdge : Graph, U64, U64, F64, F64 -> Graph
addBidirectionalEdge = \g, u, v, weight, distance ->
    g
    |> (\current -> addEdge current u v weight distance Bool.false 0)
    |> (\current -> addEdge current v u weight distance Bool.false 0)

## Get outgoing neighbors from a node
neighbors : Graph, U64 -> List Edge
neighbors = \g, u ->
    when List.get g.adj u is
        Ok edges -> edges
        Err _ -> []

## Get incoming neighbors to a node (reverse graph)
reverseNeighbors : Graph, U64 -> List Edge
reverseNeighbors = \g, u ->
    when List.get g.revAdj u is
        Ok edges -> edges
        Err _ -> []

## Compute total count of directed edges in the network
edgeCount : Graph -> U64
edgeCount = \g ->
    List.walk g.adj 0 \acc, edges -> acc + List.len edges

## Find weight of direct edge between u and v if it exists
findEdgeWeight : Graph, U64, U64 -> Result F64 [EdgeNotFound]
findEdgeWeight = \g, u, v ->
    when List.get g.adj u is
        Ok edges ->
            matched = List.walk_until edges (Err EdgeNotFound) \_, edge ->
                if edge.target == v then
                    Break (Ok edge.weight)
                else
                    Continue (Err EdgeNotFound)
            matched

        Err _ ->
            Err EdgeNotFound

expect
    g = withNodes 3
    nodeCount g == 3

expect
    g =
        withNodes 4
        |> (\g0 -> addEdge g0 0 1 10.0 10.0 Bool.false 0)
        |> (\g0 -> addEdge g0 1 2 20.0 20.0 Bool.false 0)
        |> (\g0 -> addBidirectionalEdge g0 2 3 15.0 15.0)
    edgeCount g == 4

expect
    g =
        withNodes 3
        |> (\g0 -> addEdge g0 0 1 42.0 42.0 Bool.false 0)
    when findEdgeWeight g 0 1 is
        Ok w -> Num.is_approx_eq w 42.0 { atol: 0.001 }
        Err _ -> Bool.false

expect
    g =
        withNodes 3
        |> (\g0 -> addEdge g0 0 1 42.0 42.0 Bool.false 0)
    when findEdgeWeight g 1 0 is
        Ok _ -> Bool.false
        Err EdgeNotFound -> Bool.true
