module [
    SavingPair,
    clarkeWrightSavings,
    nearestAddition,
]

import Types exposing [NodeId]
import Problem exposing [Problem, getDistance]
import Solution exposing [Solution, evaluateSolution]

SavingPair : {
    i : NodeId,
    j : NodeId,
    saving : F64,
}

## Construct initial solution using Clarke-Wright savings heuristic
clarkeWrightSavings : Problem -> Solution
clarkeWrightSavings = \problem ->
    custs = problem.customers
    custIds = List.map custs \c -> c.id
    depotId = 0
    mat = problem.matrix

    # Compute savings for all pairs (i, j) with i != j
    allPairs = generateSavingsPairs custIds depotId mat

    # Sort pairs in descending order of savings
    sortedPairs = List.sort_with allPairs \p1, p2 ->
        if p1.saving > p2.saving then LT else if p1.saving < p2.saving then GT else EQ

    # Start with each customer in its own single-customer route
    initialRoutes = List.map custIds \cid -> [cid]

    # Iteratively merge routes according to savings order if feasible
    mergedRoutes = List.walk sortedPairs initialRoutes \currentRoutes, pair ->
        tryMergeRoutes problem currentRoutes pair.i pair.j

    # Form solution
    evaluateSolution problem mergedRoutes []

generateSavingsPairs : List NodeId, NodeId, Problem.DistanceMatrix -> List SavingPair
generateSavingsPairs = \ids, depotId, mat ->
    List.walk_with_index ids [] \acc, i, idxI ->
        subsequent = List.drop_first ids (idxI + 1)
        pairsForI = List.map subsequent \j ->
            d0i = getDistance mat depotId i
            d0j = getDistance mat depotId j
            dij = getDistance mat i j
            saving = d0i + d0j - dij
            { i, j, saving }
        List.concat acc pairsForI

tryMergeRoutes : Problem, List (List NodeId), NodeId, NodeId -> List (List NodeId)
tryMergeRoutes = \problem, routes, i, j ->
    routeIdxI = findRouteWithCustomer routes i
    routeIdxJ = findRouteWithCustomer routes j

    when (routeIdxI, routeIdxJ) is
        (Ok ri, Ok rj) ->
            if ri == rj then
                # Already in same route
                routes
            else
                routeI = when List.get routes ri is
                    Ok r -> r
                    Err _ -> []
                routeJ = when List.get routes rj is
                    Ok r -> r
                    Err _ -> []

                # Check if i is at the end of routeI and j is at the beginning of routeJ
                lastI = List.last routeI
                firstJ = List.first routeJ

                when (lastI, firstJ) is
                    (Ok li, Ok fj) ->
                        if li == i && fj == j then
                            mergedCandidate = List.concat routeI routeJ
                            # Test if merged route is feasible for the vehicle
                            fleetProfile = when List.get problem.fleet ri is
                                Ok vp -> vp
                                Err _ -> {
                                    id: Num.to_u64 ri,
                                    capacity: 1000,
                                    depotId: 0,
                                    earliestStart: 0.0,
                                    latestEnd: 86400.0,
                                    fixedCost: 50.0,
                                    distanceCostPerUnit: 1.0,
                                }
                            evalResult = Solution.evaluateRoute problem fleetProfile mergedCandidate
                            if evalResult.isFeasible then
                                # Remove routeJ and replace routeI with mergedCandidate
                                filtered = List.drop_at routes rj
                                actualRi = if rj < ri then ri - 1 else ri
                                List.set filtered actualRi mergedCandidate
                            else
                                routes
                        else
                            routes

                    _ -> routes

        _ -> routes

findRouteWithCustomer : List (List NodeId), NodeId -> Result U64 [NotFound]
findRouteWithCustomer = \routes, targetId ->
    List.walk_with_index routes (Err NotFound) \acc, route, idx ->
        when acc is
            Ok _ -> acc
            Err _ ->
                if List.contains route targetId then
                    Ok idx
                else
                    Err NotFound

## Sequential nearest addition construction heuristic
nearestAddition : Problem -> Solution
nearestAddition = \problem ->
    custs = problem.customers
    allIds = List.map custs \c -> c.id
    fleet = problem.fleet

    # Greedily build routes one by one
    buildLoop problem fleet allIds [] []

buildLoop : Problem, List Types.VehicleProfile, List NodeId, List (List NodeId), List NodeId -> Solution
buildLoop = \problem, remainingFleet, unassigned, completedRoutes, currentRoute ->
    if List.is_empty unassigned then
        finalRoutes = if List.is_empty currentRoute then completedRoutes else List.append completedRoutes currentRoute
        evaluateSolution problem finalRoutes []
    else
        when List.first remainingFleet is
            Err _ ->
                # Fleet exhausted, remaining customers unassigned
                finalRoutes = if List.is_empty currentRoute then completedRoutes else List.append completedRoutes currentRoute
                evaluateSolution problem finalRoutes unassigned

            Ok currentProfile ->
                lastNode = when List.last currentRoute is
                    Ok cid -> cid
                    Err _ -> currentProfile.depotId

                # Find unassigned customer with minimum distance from lastNode that keeps route feasible
                bestCandidate = List.walk unassigned (Err NotFound) \bestSoFar, candidateId ->
                    dist = getDistance problem.matrix lastNode candidateId
                    testRoute = List.append currentRoute candidateId
                    evalRes = Solution.evaluateRoute problem currentProfile testRoute
                    if evalRes.isFeasible then
                        when bestSoFar is
                            Ok { bestDist } ->
                                if dist < bestDist then
                                    Ok { bestId: candidateId, bestDist: dist }
                                else
                                    bestSoFar

                            Err _ ->
                                Ok { bestId: candidateId, bestDist: dist }
                    else
                        bestSoFar

                when bestCandidate is
                    Ok { bestId } ->
                        newCurrent = List.append currentRoute bestId
                        newUnassigned = List.drop_if unassigned \id -> id == bestId
                        buildLoop problem remainingFleet newUnassigned completedRoutes newCurrent

                    Err _ ->
                        # Cannot add more customers to this route, close route and advance to next vehicle
                        nextFleet = List.drop_first remainingFleet 1
                        newCompleted = if List.is_empty currentRoute then completedRoutes else List.append completedRoutes currentRoute
                        buildLoop problem nextFleet unassigned newCompleted []

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c2 = { id: 2, coord: { x: 10.0, y: 0.0 }, demand: 4, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 3,
        distances: [
            0.0, 5.0, 10.0,
            5.0, 0.0, 5.0,
            10.0, 5.0, 0.0,
        ],
        travelTimes: [
            0.0, 5.0, 10.0,
            5.0, 0.0, 5.0,
            10.0, 5.0, 0.0,
        ],
    }

    prob = Problem.createProblem [d0] [c1, c2] [v1] mat

    sol = nearestAddition prob
    sol.isFeasible == Bool.true && List.len sol.routes == 1
