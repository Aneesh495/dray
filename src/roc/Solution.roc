module [
    Route,
    Solution,
    emptyRoute,
    emptySolution,
    evaluateRoute,
    evaluateSolution,
    isSolutionFeasible,
    totalSolutionDistance,
    totalSolutionCost,
]

import Types exposing [Distance, Time, Demand, NodeId, VehicleId, VehicleProfile]
import Problem exposing [Problem, getDistance, getTime, getCustomer]

## A single vehicle delivery itinerary starting and ending at a depot
Route : {
    vehicleId : VehicleId,
    depotId : NodeId,
    customers : List NodeId,
    distance : Distance,
    duration : Time,
    load : Demand,
    capacityExcess : Demand,
    timeLateness : Time,
    isFeasible : Bool,
}

## A complete routing assignment across all vehicles in the fleet
Solution : {
    routes : List Route,
    unassigned : List NodeId,
    totalDistance : Distance,
    totalCost : F64,
    isFeasible : Bool,
}

## Create an empty route for a given vehicle profile
emptyRoute : VehicleProfile -> Route
emptyRoute = \vp -> {
    vehicleId: vp.id,
    depotId: vp.depotId,
    customers: [],
    distance: 0.0,
    duration: 0.0,
    load: 0,
    capacityExcess: 0,
    timeLateness: 0.0,
    isFeasible: Bool.true,
}

## Create an empty solution with no routes and no unassigned customers
emptySolution : {} -> Solution
emptySolution = \{} -> {
    routes: [],
    unassigned: [],
    totalDistance: 0.0,
    totalCost: 0.0,
    isFeasible: Bool.true,
}

## Evaluate the operational metrics, schedule feasibility, and cumulative load of a route
evaluateRoute : Problem, VehicleProfile, List NodeId -> Route
evaluateRoute = \problem, profile, customerIds ->
    depotId = profile.depotId
    matrix = problem.matrix

    # State carried during sequential stop evaluation
    initState = {
        currentNode: depotId,
        currentTime: profile.earliestStart,
        currentLoad: 0,
        totalDist: 0.0,
        totalLateness: 0.0,
        capacityExcess: 0,
    }

    finalState = List.walk customerIds initState \acc, nextCustId ->
        # Travel leg to next customer
        legDist = getDistance matrix acc.currentNode nextCustId
        legTime = getTime matrix acc.currentNode nextCustId
        arrTime = acc.currentTime + legTime
        newDist = acc.totalDist + legDist

        when getCustomer problem nextCustId is
            Ok cust ->
                # Time window handling: wait if arriving early, penalize if arriving late
                effectiveStart = if arrTime < cust.window.ready then cust.window.ready else arrTime
                lateness = if arrTime > cust.window.due then arrTime - cust.window.due else 0.0
                depTime = effectiveStart + cust.serviceDuration

                newLoad = acc.currentLoad + cust.demand
                excess = if newLoad > profile.capacity then newLoad - profile.capacity else acc.capacityExcess

                {
                    currentNode: nextCustId,
                    currentTime: depTime,
                    currentLoad: newLoad,
                    totalDist: newDist,
                    totalLateness: acc.totalLateness + lateness,
                    capacityExcess: excess,
                }

            Err _ ->
                acc

    # Return leg from last customer back to depot
    returnDist = getDistance matrix finalState.currentNode depotId
    returnTime = getTime matrix finalState.currentNode depotId
    finishTime = finalState.currentTime + returnTime
    totalRouteDist = finalState.totalDist + returnDist

    # Check depot closing time lateness
    depotLateness =
        if finishTime > profile.latestEnd then
            finishTime - profile.latestEnd
        else
            0.0

    totalLateness = finalState.totalLateness + depotLateness
    isFeasible = (finalState.capacityExcess == 0) && (totalLateness <= 0.001)

    {
        vehicleId: profile.id,
        depotId,
        customers: customerIds,
        distance: totalRouteDist,
        duration: finishTime - profile.earliestStart,
        load: finalState.currentLoad,
        capacityExcess: finalState.capacityExcess,
        timeLateness: totalLateness,
        isFeasible,
    }

## Evaluate an entire multi-route fleet solution
evaluateSolution : Problem, List (List NodeId), List NodeId -> Solution
evaluateSolution = \problem, routeCustomerLists, unassigned ->
    fleet = problem.fleet

    routes = List.map_with_index routeCustomerLists \custIds, idx ->
        profile = when List.get fleet idx is
            Ok vp -> vp
            Err _ -> {
                id: Num.to_u64 idx,
                capacity: 1000,
                depotId: 0,
                earliestStart: 0.0,
                latestEnd: 86400.0,
                fixedCost: 50.0,
                distanceCostPerUnit: 1.0,
            }
        evaluateRoute problem profile custIds

    totalDist = List.walk routes 0.0 \acc, r -> acc + r.distance

    totalCost = List.walk routes 0.0 \acc, r ->
        fixed = if List.is_empty r.customers then 0.0 else 50.0
        distCost = r.distance * 1.0
        # Heavy penalty for infeasible schedules and unassigned customers
        capPenalty = Num.to_f64 r.capacityExcess * 1000.0
        timePenalty = r.timeLateness * 100.0
        acc + fixed + distCost + capPenalty + timePenalty

    unassignedPenalty = Num.to_f64 (List.len unassigned) * 10000.0

    allRoutesFeasible = List.walk routes Bool.true \acc, r -> acc && r.isFeasible
    isFeasible = allRoutesFeasible && List.is_empty unassigned

    {
        routes,
        unassigned,
        totalDistance: totalDist,
        totalCost: totalCost + unassignedPenalty,
        isFeasible,
    }

## Check if solution violates zero constraints
isSolutionFeasible : Solution -> Bool
isSolutionFeasible = \sol -> sol.isFeasible

## Sum of distances across all active routes
totalSolutionDistance : Solution -> Distance
totalSolutionDistance = \sol -> sol.totalDistance

## Objective function cost
totalSolutionCost : Solution -> F64
totalSolutionCost = \sol -> sol.totalCost

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 10.0, y: 0.0 }, demand: 5, window: { ready: 0.0, due: 500.0 }, serviceDuration: 10.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 2,
        distances: [0.0, 10.0, 10.0, 0.0],
        travelTimes: [0.0, 10.0, 10.0, 0.0],
    }

    prob = Problem.createProblem [d0] [c1] [v1] mat

    r = evaluateRoute prob v1 [1]

    # Total distance: 0 -> 1 (10) + 1 -> 0 (10) = 20
    distOk = Num.is_approx_eq r.distance 20.0 { atol: 0.001 }
    loadOk = r.load == 5
    feasOk = r.isFeasible == Bool.true

    distOk && loadOk && feasOk

expect
    # Empty route has zero distance
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }
    r0 = emptyRoute v1
    Num.is_approx_eq r0.distance 0.0 { atol: 0.001 } && r0.isFeasible == Bool.true
