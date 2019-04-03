module [
    twoOptIntra,
    relocateMove,
    exchangeMove,
    twoOptStarMove,
    runLocalSearch,
]

import Types exposing [NodeId]
import Problem exposing [Problem]
import Solution exposing [Solution, evaluateSolution, evaluateRoute]

## 2-opt intra-route edge swap: reverses subsequence between i and j
twoOptIntra : Problem, Solution -> Solution
twoOptIntra = \problem, solution ->
    improvedRoutes = List.map_with_index solution.routes \route, rIdx ->
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
        optimizeSingleRoute2Opt problem profile route.customers

    evaluateSolution problem improvedRoutes solution.unassigned

optimizeSingleRoute2Opt : Problem, Types.VehicleProfile, List NodeId -> List NodeId
optimizeSingleRoute2Opt = \problem, profile, customers ->
    len = List.len customers
    if len < 4 then
        customers
    else
        currentEval = evaluateRoute problem profile customers
        bestDist = currentEval.distance

        findBest2OptMove problem profile customers len bestDist

findBest2OptMove : Problem, Types.VehicleProfile, List NodeId, U64, F64 -> List NodeId
findBest2OptMove = \problem, profile, customers, len, currentBestDist ->
    # Search all pairs (i, j) with i < j
    moveResult = List.walk_with_index customers (Err NoMoveFound) \outerAcc, _, i ->
        when outerAcc is
            Ok _ -> outerAcc
            Err _ ->
                subIndices = List.drop_first (List.repeat 0 len) (i + 1)
                List.walk_with_index subIndices (Err NoMoveFound) \innerAcc, _, jRel ->
                    j = i + 1 + jRel
                    when innerAcc is
                        Ok _ -> innerAcc
                        Err _ ->
                            reversedCandidate = reverseSubsegment customers i j
                            evalCandidate = evaluateRoute problem profile reversedCandidate
                            if evalCandidate.isFeasible && evalCandidate.distance < currentBestDist - 0.001 then
                                Ok reversedCandidate
                            else
                                innerAcc

    when moveResult is
        Ok improved ->
            # Recurse until local minimum
            newEval = evaluateRoute problem profile improved
            findBest2OptMove problem profile improved len newEval.distance

        Err _ ->
            customers

reverseSubsegment : List a, U64, U64 -> List a
reverseSubsegment = \list, i, j ->
    total = List.len list
    if i >= j || j >= total then
        list
    else
        prefix = List.sublist list { start: 0, len: i }
        middle = List.sublist list { start: i, len: j - i + 1 }
        suffix = List.sublist list { start: j + 1, len: total - (j + 1) }
        reversedMiddle = List.reverse middle
        List.concat (List.concat prefix reversedMiddle) suffix

## Relocate operator: move customer from one route to another
relocateMove : Problem, Solution -> Solution
relocateMove = \problem, solution ->
    routes = List.map solution.routes \r -> r.customers
    numRoutes = List.len routes
    if numRoutes < 2 then
        solution
    else
        bestCandidate = searchBestRelocate problem solution.totalCost routes
        when bestCandidate is
            Ok newRoutes -> evaluateSolution problem newRoutes solution.unassigned
            Err _ -> solution

searchBestRelocate : Problem, F64, List (List NodeId) -> Result (List (List NodeId)) [NoMoveFound]
searchBestRelocate = \problem, baseCost, routes ->
    List.walk_with_index routes (Err NoMoveFound) \acc1, r1, idx1 ->
        when acc1 is
            Ok _ -> acc1
            Err _ ->
                List.walk_with_index routes (Err NoMoveFound) \acc2, r2, idx2 ->
                    when acc2 is
                        Ok _ -> acc2
                        Err _ ->
                            if idx1 == idx2 || List.is_empty r1 then
                                Err NoMoveFound
                            else
                                testRelocateBetweenRoutes problem baseCost routes idx1 idx2 r1 r2

testRelocateBetweenRoutes : Problem, F64, List (List NodeId), U64, U64, List NodeId, List NodeId -> Result (List (List NodeId)) [NoMoveFound]
testRelocateBetweenRoutes = \problem, baseCost, allRoutes, idx1, idx2, r1, r2 ->
    List.walk_with_index r1 (Err NoMoveFound) \acc, cid, pos1 ->
        when acc is
            Ok _ -> acc
            Err _ ->
                r1MinusC = List.drop_at r1 pos1
                r2Len = List.len r2
                # Try all insertion positions in r2
                List.walk_with_index (List.repeat 0 (r2Len + 1)) (Err NoMoveFound) \innerAcc, _, pos2 ->
                    when innerAcc is
                        Ok _ -> innerAcc
                        Err _ ->
                            r2PlusC = insertAt r2 pos2 cid
                            candidateRoutes =
                                allRoutes
                                |> (\l -> List.set l idx1 r1MinusC)
                                |> (\l -> List.set l idx2 r2PlusC)
                            candidateSol = evaluateSolution problem candidateRoutes []
                            if candidateSol.isFeasible && candidateSol.totalCost < baseCost - 0.001 then
                                Ok candidateRoutes
                            else
                                innerAcc

## Exchange operator: swap customer between two routes
exchangeMove : Problem, Solution -> Solution
exchangeMove = \problem, solution ->
    routes = List.map solution.routes \r -> r.customers
    numRoutes = List.len routes
    if numRoutes < 2 then
        solution
    else
        bestSwap = searchBestExchange problem solution.totalCost routes numRoutes
        when bestSwap is
            Ok newRoutes -> evaluateSolution problem newRoutes solution.unassigned
            Err _ -> solution

searchBestExchange : Problem, F64, List (List NodeId), U64 -> Result (List (List NodeId)) [NoMoveFound]
searchBestExchange = \problem, baseCost, routes, numRoutes ->
    List.walk_with_index routes (Err NoMoveFound) \acc1, r1, idx1 ->
        when acc1 is
            Ok _ -> acc1
            Err _ ->
                subsequentRoutes = List.drop_first (List.repeat 0 numRoutes) (idx1 + 1)
                List.walk_with_index subsequentRoutes (Err NoMoveFound) \acc2, _, relIdx2 ->
                    idx2 = idx1 + 1 + relIdx2
                    when acc2 is
                        Ok _ -> acc2
                        Err _ ->
                            when List.get routes idx2 is
                                Ok r2 ->
                                    testExchangeBetweenRoutes problem baseCost routes idx1 idx2 r1 r2

                                Err _ ->
                                    Err NoMoveFound

testExchangeBetweenRoutes : Problem, F64, List (List NodeId), U64, U64, List NodeId, List NodeId -> Result (List (List NodeId)) [NoMoveFound]
testExchangeBetweenRoutes = \problem, baseCost, allRoutes, idx1, idx2, r1, r2 ->
    List.walk_with_index r1 (Err NoMoveFound) \acc, c1, p1 ->
        when acc is
            Ok _ -> acc
            Err _ ->
                List.walk_with_index r2 (Err NoMoveFound) \innerAcc, c2, p2 ->
                    when innerAcc is
                        Ok _ -> innerAcc
                        Err _ ->
                            newR1 = List.set r1 p1 c2
                            newR2 = List.set r2 p2 c1
                            candidateRoutes =
                                allRoutes
                                |> (\l -> List.set l idx1 newR1)
                                |> (\l -> List.set l idx2 newR2)
                            candidateSol = evaluateSolution problem candidateRoutes []
                            if candidateSol.isFeasible && candidateSol.totalCost < baseCost - 0.001 then
                                Ok candidateRoutes
                            else
                                innerAcc

## 2-opt* inter-route operator: swaps tails of two routes
twoOptStarMove : Problem, Solution -> Solution
twoOptStarMove = \problem, solution ->
    routes = List.map solution.routes \r -> r.customers
    numRoutes = List.len routes
    if numRoutes < 2 then
        solution
    else
        best2OptStar = searchBest2OptStar problem solution.totalCost routes numRoutes
        when best2OptStar is
            Ok newRoutes -> evaluateSolution problem newRoutes solution.unassigned
            Err _ -> solution

searchBest2OptStar : Problem, F64, List (List NodeId), U64 -> Result (List (List NodeId)) [NoMoveFound]
searchBest2OptStar = \problem, baseCost, routes, numRoutes ->
    List.walk_with_index routes (Err NoMoveFound) \acc1, r1, idx1 ->
        when acc1 is
            Ok _ -> acc1
            Err _ ->
                subsequentRoutes = List.drop_first (List.repeat 0 numRoutes) (idx1 + 1)
                List.walk_with_index subsequentRoutes (Err NoMoveFound) \acc2, _, relIdx2 ->
                    idx2 = idx1 + 1 + relIdx2
                    when acc2 is
                        Ok _ -> acc2
                        Err _ ->
                            when List.get routes idx2 is
                                Ok r2 ->
                                    test2OptStarBetweenRoutes problem baseCost routes idx1 idx2 r1 r2

                                Err _ ->
                                    Err NoMoveFound

test2OptStarBetweenRoutes : Problem, F64, List (List NodeId), U64, U64, List NodeId, List NodeId -> Result (List (List NodeId)) [NoMoveFound]
test2OptStarBetweenRoutes = \problem, baseCost, allRoutes, idx1, idx2, r1, r2 ->
    len1 = List.len r1
    len2 = List.len r2
    List.walk_with_index (List.repeat 0 (len1 + 1)) (Err NoMoveFound) \acc, _, split1 ->
        when acc is
            Ok _ -> acc
            Err _ ->
                List.walk_with_index (List.repeat 0 (len2 + 1)) (Err NoMoveFound) \innerAcc, _, split2 ->
                    when innerAcc is
                        Ok _ -> innerAcc
                        Err _ ->
                            head1 = List.sublist r1 { start: 0, len: split1 }
                            tail1 = List.sublist r1 { start: split1, len: len1 - split1 }
                            head2 = List.sublist r2 { start: 0, len: split2 }
                            tail2 = List.sublist r2 { start: split2, len: len2 - split2 }

                            newR1 = List.concat head1 tail2
                            newR2 = List.concat head2 tail1

                            candidateRoutes =
                                allRoutes
                                |> (\l -> List.set l idx1 newR1)
                                |> (\l -> List.set l idx2 newR2)
                            candidateSol = evaluateSolution problem candidateRoutes []
                            if candidateSol.isFeasible && candidateSol.totalCost < baseCost - 0.001 then
                                Ok candidateRoutes
                            else
                                innerAcc

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

## Combined local search loop applying operators until convergence
runLocalSearch : Problem, Solution, U64 -> Solution
runLocalSearch = \problem, currentSolution, maxIterations ->
    if maxIterations == 0 then
        currentSolution
    else
        step1 = twoOptIntra problem currentSolution
        step2 = if step1.totalCost < currentSolution.totalCost then step1 else relocateMove problem step1
        step3 = if step2.totalCost < step1.totalCost then step2 else exchangeMove problem step2
        step4 = if step3.totalCost < step2.totalCost then step3 else twoOptStarMove problem step3

        if step4.totalCost < currentSolution.totalCost - 0.001 then
            runLocalSearch problem step4 (maxIterations - 1)
        else
            currentSolution

expect
    # Test 2-opt subsegment reversal
    reversed = reverseSubsegment [1, 2, 3, 4, 5] 1 3
    reversed == [1, 4, 3, 2, 5]

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 10.0, y: 0.0 }, demand: 2, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c2 = { id: 2, coord: { x: 20.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c3 = { id: 3, coord: { x: 30.0, y: 0.0 }, demand: 2, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c4 = { id: 4, coord: { x: 40.0, y: 0.0 }, demand: 1, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 5,
        distances: [
            0.0, 10.0, 20.0, 30.0, 40.0,
            10.0, 0.0, 10.0, 20.0, 30.0,
            20.0, 10.0, 0.0, 10.0, 20.0,
            30.0, 20.0, 10.0, 0.0, 10.0,
            40.0, 30.0, 20.0, 10.0, 0.0,
        ],
        travelTimes: [
            0.0, 10.0, 20.0, 30.0, 40.0,
            10.0, 0.0, 10.0, 20.0, 30.0,
            20.0, 10.0, 0.0, 10.0, 20.0,
            30.0, 20.0, 10.0, 0.0, 10.0,
            40.0, 30.0, 20.0, 10.0, 0.0,
        ],
    }

    prob = Problem.createProblem [d0] [c1, c2, c3, c4] [v1] mat

    # Route with criss-crossed order: [1, 3, 2, 4]
    sol = evaluateSolution prob [[1, 3, 2, 4]] []
    improved = twoOptIntra prob sol

    # 2-opt should untangle to [1, 2, 3, 4] or lower distance
    improved.totalDistance <= sol.totalDistance
