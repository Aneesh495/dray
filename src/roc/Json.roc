module [
    serializeSolutionJson,
    serializeMetricsJson,
]

import Solution exposing [Solution, Route]
import Metrics exposing [FleetMetrics]

## Serialize a Solution into standard JSON format
serializeSolutionJson : Solution -> Str
serializeSolutionJson = \sol ->
    routesJson = List.map sol.routes serializeRouteJson
    joinedRoutes = Str.join_with routesJson ","
    unassignedJson = List.map sol.unassigned Num.to_str
    joinedUnassigned = Str.join_with unassignedJson ","

    feasStr = if sol.isFeasible then "true" else "false"
    distStr = Num.to_str sol.totalDistance
    costStr = Num.to_str sol.totalCost

    Str.concat "{\"is_feasible\":" feasStr
    |> Str.concat ",\"total_distance\":"
    |> Str.concat distStr
    |> Str.concat ",\"total_cost\":"
    |> Str.concat costStr
    |> Str.concat ",\"routes\":["
    |> Str.concat joinedRoutes
    |> Str.concat "],\"unassigned\":["
    |> Str.concat joinedUnassigned
    |> Str.concat "]}"

serializeRouteJson : Route -> Str
serializeRouteJson = \r ->
    custsStr = List.map r.customers Num.to_str
    joinedCusts = Str.join_with custsStr ","

    vStr = Num.to_str r.vehicleId
    dStr = Num.to_str r.depotId
    distStr = Num.to_str r.distance
    durStr = Num.to_str r.duration
    loadStr = Num.to_str r.load

    Str.concat "{\"vehicle_id\":" vStr
    |> Str.concat ",\"depot_id\":"
    |> Str.concat dStr
    |> Str.concat ",\"distance\":"
    |> Str.concat distStr
    |> Str.concat ",\"duration\":"
    |> Str.concat durStr
    |> Str.concat ",\"load\":"
    |> Str.concat loadStr
    |> Str.concat ",\"customers\":["
    |> Str.concat joinedCusts
    |> Str.concat "]}"

## Serialize FleetMetrics into standard JSON format
serializeMetricsJson : FleetMetrics -> Str
serializeMetricsJson = \m ->
    kmStr = Num.to_str m.totalDistanceKm
    hStr = Num.to_str m.totalDurationHours
    vehStr = Num.to_str m.activeVehicleCount
    utilStr = Num.to_str m.capacityUtilization
    carbStr = Num.to_str m.totalCarbonKg

    Str.concat "{\"total_distance_km\":" kmStr
    |> Str.concat ",\"total_duration_hours\":"
    |> Str.concat hStr
    |> Str.concat ",\"active_vehicle_count\":"
    |> Str.concat vehStr
    |> Str.concat ",\"capacity_utilization\":"
    |> Str.concat utilStr
    |> Str.concat ",\"total_carbon_kg\":"
    |> Str.concat carbStr
    |> Str.concat "}"

expect
    r1 = {
        vehicleId: 1,
        depotId: 0,
        customers: [2, 3],
        distance: 15.0,
        duration: 300.0,
        load: 20,
        capacityExcess: 0,
        timeLateness: 0.0,
        isFeasible: Bool.true,
    }
    sol = {
        routes: [r1],
        unassigned: [],
        totalDistance: 15.0,
        totalCost: 65.0,
        isFeasible: Bool.true,
    }
    json = serializeSolutionJson sol
    Str.contains json "\"is_feasible\":true" && Str.contains json "\"vehicle_id\":1"
