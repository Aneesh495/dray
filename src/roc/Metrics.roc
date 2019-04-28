module [
    FleetMetrics,
    computeFleetMetrics,
    estimateCarbonGrams,
]

import Problem exposing [Problem]
import Solution exposing [Solution]

FleetMetrics : {
    totalDistanceKm : F64,
    totalDurationHours : F64,
    activeVehicleCount : U64,
    capacityUtilization : F64,
    totalCarbonKg : F64,
    averageWaitTimeSec : F64,
    unassignedCount : U64,
}

## Compute comprehensive logistics fleet performance metrics from a solution
computeFleetMetrics : Problem, Solution -> FleetMetrics
computeFleetMetrics = \problem, solution ->
    totalDistMeters = solution.totalDistance
    totalDistKm = totalDistMeters / 1000.0

    totalDurationSec = List.walk solution.routes 0.0 \acc, r -> acc + r.duration
    totalDurationHours = totalDurationSec / 3600.0

    activeRoutes = List.drop_if solution.routes \r -> List.is_empty r.customers
    activeCount = List.len activeRoutes

    totalCarried = List.walk activeRoutes 0 \acc, r -> acc + r.load
    totalAvailableCap = List.walk_with_index activeRoutes 0 \acc, _, rIdx ->
        cap = when List.get problem.fleet rIdx is
            Ok vp -> vp.capacity
            Err _ -> 100
        acc + cap

    utilization =
        if totalAvailableCap > 0 then
            (Num.to_f64 totalCarried) / (Num.to_f64 totalAvailableCap)
        else
            0.0

    carbonKg = estimateCarbonGrams totalDistKm / 1000.0
    unassigned = List.len solution.unassigned

    {
        totalDistanceKm: totalDistKm,
        totalDurationHours,
        activeVehicleCount: activeCount,
        capacityUtilization: utilization,
        totalCarbonKg: carbonKg,
        averageWaitTimeSec: 0.0,
        unassignedCount: unassigned,
    }

## Estimate carbon emissions in grams assuming average diesel van rate of 160g CO2 / km
estimateCarbonGrams : F64 -> F64
estimateCarbonGrams = \distanceKm ->
    distanceKm * 160.0

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5000.0, y: 0.0 }, demand: 10, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 2,
        distances: [0.0, 5000.0, 5000.0, 0.0],
        travelTimes: [0.0, 300.0, 300.0, 0.0],
    }

    prob = Problem.createProblem [d0] [c1] [v1] mat
    sol = Solution.evaluateSolution prob [[1]] []

    metrics = computeFleetMetrics prob sol

    # 10,000 meters = 10 km
    kmOk = Num.is_approx_eq metrics.totalDistanceKm 10.0 { atol: 0.01 }
    # 10 demand / 20 capacity = 0.5 utilization
    utilOk = Num.is_approx_eq metrics.capacityUtilization 0.5 { atol: 0.01 }
    # 10 km * 160 g = 1600 g = 1.6 kg
    carbOk = Num.is_approx_eq metrics.totalCarbonKg 1.6 { atol: 0.01 }

    kmOk && utilOk && carbOk
