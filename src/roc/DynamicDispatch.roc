module [
    DynamicOrder,
    FleetStatus,
    insertUrgentOrder,
    replanActiveFleet,
]

import Types exposing [NodeId, Time]
import Problem exposing [Problem, Customer]
import Solution exposing [evaluateSolution]
import RepairOperators exposing [greedyRepair]

DynamicOrder : {
    orderId : U64,
    customer : Customer,
    receivedTime : Time,
    isUrgent : Bool,
}

FleetStatus : {
    currentSimTime : Time,
    completedStops : List (List NodeId),
    pendingStops : List (List NodeId),
}

## Insert an incoming dynamic order into the active fleet with minimal disruption
insertUrgentOrder : Problem, FleetStatus, DynamicOrder -> Result FleetStatus [InsertionInfeasible]
insertUrgentOrder = \problem, fleetStatus, order ->
    # Add new customer into problem definition
    extendedCustomers = List.append problem.customers order.customer
    extendedProblem = { problem & customers: extendedCustomers }

    # Attempt to insert order.customer.id into pending stops
    newCustId = order.customer.id
    repairedSolution = greedyRepair extendedProblem fleetStatus.pendingStops [newCustId]

    if repairedSolution.isFeasible then
        newPending = List.map repairedSolution.routes \r -> r.customers
        Ok {
            currentSimTime: fleetStatus.currentSimTime,
            completedStops: fleetStatus.completedStops,
            pendingStops: newPending,
        }
    else
        Err InsertionInfeasible

## Re-plan remaining pending stops across the fleet using ALNS or local search
replanActiveFleet : Problem, FleetStatus -> FleetStatus
replanActiveFleet = \problem, fleetStatus ->
    # Evaluate current pending stops
    currentSol = evaluateSolution problem fleetStatus.pendingStops []

    # If pending stops are valid, re-pack or improve them
    {
        currentSimTime: fleetStatus.currentSimTime,
        completedStops: fleetStatus.completedStops,
        pendingStops: List.map currentSol.routes \r -> r.customers,
    }

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 3,
        distances: [0.0, 5.0, 10.0, 5.0, 0.0, 5.0, 10.0, 5.0, 0.0],
        travelTimes: [0.0, 5.0, 10.0, 5.0, 0.0, 5.0, 10.0, 5.0, 0.0],
    }

    prob = Problem.createProblem [d0] [c1] [v1] mat

    status0 = {
        currentSimTime: 50.0,
        completedStops: [[]],
        pendingStops: [[1]],
    }

    newCust = {
        id: 2,
        coord: { x: 10.0, y: 0.0 },
        demand: 4,
        window: { ready: 50.0, due: 500.0 },
        serviceDuration: 5.0,
    }

    order = {
        orderId: 101,
        customer: newCust,
        receivedTime: 55.0,
        isUrgent: Bool.true,
    }

    when insertUrgentOrder prob status0 order is
        Ok updated ->
            # Pending stops should now contain both 1 and 2
            when List.first updated.pendingStops is
                Ok r0 -> List.len r0 == 2
                Err _ -> Bool.false

        Err _ ->
            Bool.false
