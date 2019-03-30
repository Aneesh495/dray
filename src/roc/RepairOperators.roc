module [
    greedyRepair,
    regret2Repair,
    regret3Repair,
]

import Types exposing [NodeId]
import Problem exposing [Problem, getDistance]
import Solution exposing [Solution, evaluateSolution, evaluateRoute]

InsertionCandidate : {
    customerId : NodeId,
    routeIndex : U64,
    position : U64,
    addedCost : F64,
}

## Greedy repair: iteratively inserts customer with lowest feasible insertion cost
greedyRepair : Problem, List (List NodeId), List NodeId -> Solution
greedyRepair = \problem, routes, unassigned ->
    repairLoop problem routes unassigned

repairLoop : Problem, List (List NodeId), List NodeId -> Solution
repairLoop = \problem, routes, unassigned ->
    if List.is_empty unassigned then
        evaluateSolution problem routes []
    else
        # Find candidate with absolute lowest added cost across all customers
        bestOption = List.walk unassigned (Err NoFeasibleInsertion) \overallBest, cid ->
            when findBestInsertionForCustomer problem routes cid is
                Ok candidate ->
                    when overallBest is
                        Ok cur ->
                            if candidate.addedCost < cur.addedCost then
                                Ok candidate
                            else
                                overallBest

                        Err _ ->
                            Ok candidate

                Err _ ->
                    overallBest

        when bestOption is
            Ok best ->
                # Apply insertion
                newRoutes = insertIntoRoutes routes best.routeIndex best.position best.customerId
                newUnassigned = List.drop_if unassigned \id -> id == best.customerId
                repairLoop problem newRoutes newUnassigned

            Err _ ->
                # No feasible insertion in existing routes; try opening a new route with next vehicle
                fleetTotal = List.len problem.fleet
                activeRoutesCount = List.len routes
                if activeRoutesCount < fleetTotal then
                    when List.first unassigned is
                        Ok nextCust ->
                            newRoutes = List.append routes [nextCust]
                            newUnassigned = List.drop_first unassigned 1
                            repairLoop problem newRoutes newUnassigned

                        Err _ ->
                            evaluateSolution problem routes unassigned
                else
                    evaluateSolution problem routes unassigned

## Regret-2 repair: prioritizes customer with largest difference between 2nd best and best insertion
regret2Repair : Problem, List (List NodeId), List NodeId -> Solution
regret2Repair = \problem, routes, unassigned ->
    regretLoop problem routes unassigned 2

## Regret-3 repair: prioritizes customer with largest cumulative regret across 3 best positions
regret3Repair : Problem, List (List NodeId), List NodeId -> Solution
regret3Repair = \problem, routes, unassigned ->
    regretLoop problem routes unassigned 3

regretLoop : Problem, List (List NodeId), List NodeId, U64 -> Solution
regretLoop = \problem, routes, unassigned, k ->
    if List.is_empty unassigned then
        evaluateSolution problem routes []
    else
        # Evaluate regret value for each unassigned customer
        scoredCustomers = List.walk unassigned [] \acc, cid ->
            allInsertions = findAllInsertionsForCustomer problem routes cid
            sorted = List.sort_with allInsertions \c1, c2 ->
                if c1.addedCost < c2.addedCost then LT else if c1.addedCost > c2.addedCost then GT else EQ

            when List.first sorted is
                Ok bestCand ->
                    regretVal = computeRegretValue sorted k
                    List.append acc { candidate: bestCand, regret: regretVal }

                Err _ ->
                    acc

        # Pick customer with MAXIMUM regret value
        maxRegretPick = List.walk scoredCustomers (Err NoFeasibleInsertion) \bestSoFar, entry ->
            when bestSoFar is
                Ok cur ->
                    if entry.regret > cur.regret then Ok entry else bestSoFar

                Err _ ->
                    Ok entry

        when maxRegretPick is
            Ok { candidate } ->
                newRoutes = insertIntoRoutes routes candidate.routeIndex candidate.position candidate.customerId
                newUnassigned = List.drop_if unassigned \id -> id == candidate.customerId
                regretLoop problem newRoutes newUnassigned k

            Err _ ->
                # Fallback to greedy or new route
                greedyRepair problem routes unassigned

computeRegretValue : List InsertionCandidate, U64 -> F64
computeRegretValue = \sortedList, k ->
    when List.first sortedList is
        Ok first ->
            bestCost = first.addedCost
            topK = List.take_first sortedList k
            List.walk topK 0.0 \acc, cand ->
                acc + (cand.addedCost - bestCost)

        Err _ ->
            0.0

findBestInsertionForCustomer : Problem, List (List NodeId), NodeId -> Result InsertionCandidate [NoFeasibleInsertion]
findBestInsertionForCustomer = \problem, routes, customerId ->
    all = findAllInsertionsForCustomer problem routes customerId
    List.walk all (Err NoFeasibleInsertion) \bestSoFar, cand ->
        when bestSoFar is
            Ok cur ->
                if cand.addedCost < cur.addedCost then Ok cand else bestSoFar

            Err _ ->
                Ok cand

findAllInsertionsForCustomer : Problem, List (List NodeId), NodeId -> List InsertionCandidate
findAllInsertionsForCustomer = \problem, routes, customerId ->
    mat = problem.matrix
    List.walk_with_index routes [] \acc, route, rIdx ->
        profile = when List.get problem.fleet rIdx is
            Ok vp -> vp
            Err _ -> {
                id: Num.to_u64 rIdx,
                capacity: 1000,
                depotId: 0,
                earliestStart: 0.0,
                latestEnd: 86400.0,
                fixedCost: 50.0,
                distanceCostPerUnit: 1.0,
            }

        len = List.len route
        # Positions: 0 to len inclusive
        insertionsInRoute = List.walk_with_index (List.repeat 0 (len + 1)) [] \subAcc, _, posIdx ->
            candidateRoute = insertAt route posIdx customerId
            evalResult = evaluateRoute problem profile candidateRoute
            if evalResult.isFeasible then
                # Compute marginal distance added
                prevNode =
                    if posIdx == 0 then
                        profile.depotId
                    else
                        when List.get route (posIdx - 1) is
                            Ok id -> id
                            Err _ -> profile.depotId

                nextNode =
                    if posIdx == len then
                        profile.depotId
                    else
                        when List.get route posIdx is
                            Ok id -> id
                            Err _ -> profile.depotId

                dOld = getDistance mat prevNode nextNode
                dNew = getDistance mat prevNode customerId + getDistance mat customerId nextNode
                costAdded = dNew - dOld

                List.append subAcc {
                    customerId,
                    routeIndex: rIdx,
                    position: posIdx,
                    addedCost: costAdded,
                }
            else
                subAcc

        List.concat acc insertionsInRoute

insertAt : List a, U64, a -> List a
insertAt = \list, pos, item ->
    total = List.len list
    if pos >= total then
        List.append list item
    else if pos == 0 then
        List.prepend list item
    else
        left = List.sublist list { start: 0, len: pos }
        right = List.sublist list { start: pos, len: total - pos }
        List.concat (List.append left item) right

insertIntoRoutes : List (List NodeId), U64, U64, NodeId -> List (List NodeId)
insertIntoRoutes = \routes, rIdx, pos, item ->
    when List.get routes rIdx is
        Ok route ->
            updatedRoute = insertAt route pos item
            List.set routes rIdx updatedRoute

        Err _ ->
            List.append routes [item]

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

    # Route has [1], unassigned has [2]. Greedy repair should insert 2 after 1.
    sol = greedyRepair prob [[1]] [2]
    sol.isFeasible == Bool.true && sol.unassigned == []

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

    sol = regret2Repair prob [[1]] [2]
    sol.isFeasible == Bool.true && sol.unassigned == []
