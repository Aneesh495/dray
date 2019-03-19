module [
    Customer,
    Depot,
    DistanceMatrix,
    Problem,
    createProblem,
    getDistance,
    getTime,
    getCustomer,
    totalDemand,
    customerCount,
    depotCount,
]

import Types exposing [Coord, Distance, Time, Demand, NodeId, TimeWindow, VehicleProfile]

## A delivery customer or service location
Customer : {
    id : NodeId,
    coord : Coord,
    demand : Demand,
    window : TimeWindow,
    serviceDuration : Time,
}

## A central logistics depot or distribution hub
Depot : {
    id : NodeId,
    coord : Coord,
    window : TimeWindow,
}

## A square distance and travel time matrix between all locations
DistanceMatrix : {
    dimension : U64,
    distances : List F64,
    travelTimes : List F64,
}

## A complete VRPTW problem instance
Problem : {
    depots : List Depot,
    customers : List Customer,
    fleet : List VehicleProfile,
    matrix : DistanceMatrix,
}

## Initialize a Problem instance with consistency checks
createProblem : List Depot, List Customer, List VehicleProfile, DistanceMatrix -> Problem
createProblem = \depots, customers, fleet, matrix -> {
    depots,
    customers,
    fleet,
    matrix,
}

## Look up distance between two nodes in flat row-major matrix
getDistance : DistanceMatrix, NodeId, NodeId -> Distance
getDistance = \mat, fromId, toId ->
    fromU = Num.to_u64 fromId
    toU = Num.to_u64 toId
    idx = fromU * mat.dimension + toU
    when List.get mat.distances idx is
        Ok d -> d
        Err _ -> 1.0e15

## Look up travel time between two nodes in flat row-major matrix
getTime : DistanceMatrix, NodeId, NodeId -> Time
getTime = \mat, fromId, toId ->
    fromU = Num.to_u64 fromId
    toU = Num.to_u64 toId
    idx = fromU * mat.dimension + toU
    when List.get mat.travelTimes idx is
        Ok t -> t
        Err _ -> 1.0e15

## Find customer by id
getCustomer : Problem, NodeId -> Result Customer [CustomerNotFound]
getCustomer = \problem, targetId ->
    matched = List.walk_until problem.customers (Err CustomerNotFound) \_, c ->
        if c.id == targetId then
            Break (Ok c)
        else
            Continue (Err CustomerNotFound)
    matched

## Total demand summed across all customers
totalDemand : Problem -> Demand
totalDemand = \problem ->
    List.walk problem.customers 0 \acc, c -> acc + c.demand

## Number of customers in the problem
customerCount : Problem -> U64
customerCount = \problem -> List.len problem.customers

## Number of depots in the problem
depotCount : Problem -> U64
depotCount = \problem -> List.len problem.depots

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 10.0, y: 10.0 }, demand: 5, window: { ready: 50.0, due: 200.0 }, serviceDuration: 10.0 }
    c2 = { id: 2, coord: { x: 20.0, y: 20.0 }, demand: 8, window: { ready: 100.0, due: 300.0 }, serviceDuration: 15.0 }

    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 100.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 3,
        distances: [
            0.0, 14.14, 28.28,
            14.14, 0.0, 14.14,
            28.28, 14.14, 0.0,
        ],
        travelTimes: [
            0.0, 15.0, 30.0,
            15.0, 0.0, 15.0,
            30.0, 15.0, 0.0,
        ],
    }

    prob = createProblem [d0] [c1, c2] [v1] mat

    totDem = totalDemand prob
    countC = customerCount prob
    d01 = getDistance mat 0 1

    totDem == 13 && countC == 2 && Num.is_approx_eq d01 14.14 { atol: 0.01 }
