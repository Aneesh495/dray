module [
    DestroyResult,
    randomRemoval,
    worstCostRemoval,
    shawRemoval,
    routeRemoval,
]

import Types exposing [NodeId]
import Problem exposing [Problem, getDistance, getCustomer]
import Solution exposing [Solution, evaluateSolution]

DestroyResult : {
    routes : List (List NodeId),
    removed : List NodeId,
}

## Random removal: remove q customers selected using a deterministic pseudo-random sequence
randomRemoval : Solution, U64, U64 -> DestroyResult
randomRemoval = \solution, q, seed ->
    # Flatten all customer IDs from current routes
    allCusts = List.join (List.map solution.routes \r -> r.customers)
    totalCusts = List.len allCusts

    qActual = if q > totalCusts then totalCusts else q

    # Deterministic permutation using linear congruential sequence
    indicesToRemove = pickPseudoRandomIndices totalCusts qActual seed []

    toRemoveSet = List.map indicesToRemove \idx ->
        when List.get allCusts idx is
            Ok cid -> cid
            Err _ -> 0

    # Filter out removed customers from routes
    newRoutes = List.map solution.routes \r ->
        List.drop_if r.customers \cid -> List.contains toRemoveSet cid

    # Clean empty routes
    nonEmpty = List.drop_if newRoutes \r -> List.is_empty r

    { routes: nonEmpty, removed: toRemoveSet }

pickPseudoRandomIndices : U64, U64, U64, List U64 -> List U64
pickPseudoRandomIndices = \total, countRemaining, currentSeed, acc ->
    if countRemaining == 0 || total == 0 then
        acc
    else
        nextSeed = (currentSeed * 1103515245 + 12345) % 2147483648
        targetIdx = nextSeed % total
        if List.contains acc targetIdx then
            pickPseudoRandomIndices total countRemaining nextSeed acc
        else
            pickPseudoRandomIndices total (countRemaining - 1) nextSeed (List.append acc targetIdx)

## Worst-cost removal: remove customers whose removal yields the largest reduction in route distance
worstCostRemoval : Problem, Solution, U64 -> DestroyResult
worstCostRemoval = \problem, solution, q ->
    savings = computeAllCustomerRemovalSavings problem solution

    # Sort customers by distance reduction descending
    sorted = List.sort_with savings \s1, s2 ->
        if s1.saving > s2.saving then LT else if s1.saving < s2.saving then GT else EQ

    selectedToRemove = List.take_first sorted q
    toRemoveIds = List.map selectedToRemove \s -> s.id

    newRoutes = List.map solution.routes \r ->
        List.drop_if r.customers \cid -> List.contains toRemoveIds cid

    nonEmpty = List.drop_if newRoutes \r -> List.is_empty r

    { routes: nonEmpty, removed: toRemoveIds }

CustomerSaving : {
    id : NodeId,
    saving : F64,
}

computeAllCustomerRemovalSavings : Problem, Solution -> List CustomerSaving
computeAllCustomerRemovalSavings = \problem, solution ->
    mat = problem.matrix
    List.walk solution.routes [] \acc, route ->
        depot = route.depotId
        custs = route.customers
        len = List.len custs

        routeSavings = List.map_with_index custs \cid, idx ->
            prevId =
                if idx == 0 then
                    depot
                else
                    when List.get custs (idx - 1) is
                        Ok id -> id
                        Err _ -> depot

            nextId =
                if idx + 1 == len then
                    depot
                else
                    when List.get custs (idx + 1) is
                        Ok id -> id
                        Err _ -> depot

            dPrevCur = getDistance mat prevId cid
            dCurNext = getDistance mat cid nextId
            dPrevNext = getDistance mat prevId nextId

            costReduction = dPrevCur + dCurNext - dPrevNext
            { id: cid, saving: costReduction }

        List.concat acc routeSavings

## Shaw similarity removal: remove customers that are spatially and temporally related
shawRemoval : Problem, Solution, U64, NodeId -> DestroyResult
shawRemoval = \problem, solution, q, pivotId ->
    allCusts = List.join (List.map solution.routes \r -> r.customers)

    when getCustomer problem pivotId is
        Err _ ->
            # Fallback to random if pivot not found
            randomRemoval solution q 42

        Ok pivotCust ->
            # Compute Shaw relatedness metric for each customer
            scored = List.map allCusts \cid ->
                when getCustomer problem cid is
                    Ok c ->
                        dist = getDistance problem.matrix pivotId cid
                        demDiff = Num.abs (c.demand - pivotCust.demand)
                        timeDiff = Num.abs (c.window.ready - pivotCust.window.ready)
                        relatedness = dist * 0.6 + (Num.to_f64 demDiff) * 0.2 + timeDiff * 0.2
                        { id: cid, score: relatedness }

                    Err _ ->
                        { id: cid, score: 1.0e15 }

            # Sort ascending: lowest score = most related
            sorted = List.sort_with scored \s1, s2 ->
                if s1.score < s2.score then LT else if s1.score > s2.score then GT else EQ

            chosenToRemove = List.take_first sorted q
            toRemoveIds = List.map chosenToRemove \s -> s.id

            newRoutes = List.map solution.routes \r ->
                List.drop_if r.customers \cid -> List.contains toRemoveIds cid

            nonEmpty = List.drop_if newRoutes \r -> List.is_empty r

            { routes: nonEmpty, removed: toRemoveIds }

## Route removal: destroy an entire vehicle route to encourage compaction
routeRemoval : Solution, U64 -> DestroyResult
routeRemoval = \solution, routeIndex ->
    total = List.len solution.routes
    if routeIndex >= total then
        { routes: List.map solution.routes \r -> r.customers, removed: [] }
    else
        when List.get solution.routes routeIndex is
            Ok targetRoute ->
                remaining = List.drop_at solution.routes routeIndex
                remainingCustLists = List.map remaining \r -> r.customers
                { routes: remainingCustLists, removed: targetRoute.customers }

            Err _ ->
                { routes: List.map solution.routes \r -> r.customers, removed: [] }

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c2 = { id: 2, coord: { x: 10.0, y: 0.0 }, demand: 4, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c3 = { id: 3, coord: { x: 15.0, y: 0.0 }, demand: 2, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 4,
        distances: [
            0.0, 5.0, 10.0, 15.0,
            5.0, 0.0, 5.0, 10.0,
            10.0, 5.0, 0.0, 5.0,
            15.0, 10.0, 5.0, 0.0,
        ],
        travelTimes: [
            0.0, 5.0, 10.0, 15.0,
            5.0, 0.0, 5.0, 10.0,
            10.0, 5.0, 0.0, 5.0,
            15.0, 10.0, 5.0, 0.0,
        ],
    }

    prob = Problem.createProblem [d0] [c1, c2, c3] [v1] mat
    sol = evaluateSolution prob [[1, 2, 3]] []

    # Destroy 1 customer via random removal
    dest = randomRemoval sol 1 12345
    List.len dest.removed == 1

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c2 = { id: 2, coord: { x: 10.0, y: 0.0 }, demand: 4, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 3,
        distances: [0.0, 5.0, 10.0, 5.0, 0.0, 5.0, 10.0, 5.0, 0.0],
        travelTimes: [0.0, 5.0, 10.0, 5.0, 0.0, 5.0, 10.0, 5.0, 0.0],
    }

    prob = Problem.createProblem [d0] [c1, c2] [v1] mat
    sol = evaluateSolution prob [[1, 2]] []

    destRoute = routeRemoval sol 0
    List.len destRoute.removed == 2 && List.is_empty destRoute.routes
