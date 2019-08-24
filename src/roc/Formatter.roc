module [
    formatRouteTable,
    formatMetricsSummary,
]

import Solution exposing [Solution, Route]
import Metrics exposing [FleetMetrics]

## Format a human-readable ASCII table of vehicle routes
formatRouteTable : Solution -> Str
formatRouteTable = \sol ->
    header = "VEHICLE | DEPOT | DISTANCE (KM) | DURATION (H) | LOAD | STOPS\n--------------------------------------------------------------\n"
    rows = List.map sol.routes formatSingleRoute
    joinedRows = Str.join_with rows "\n"
    Str.concat header joinedRows

formatSingleRoute : Route -> Str
formatSingleRoute = \r ->
    vStr = Num.to_str r.vehicleId
    dStr = Num.to_str r.depotId
    kmStr = Num.to_str (r.distance / 1000.0)
    durStr = Num.to_str (r.duration / 3600.0)
    loadStr = Num.to_str r.load

    stopsStr = Str.join_with (List.map r.customers Num.to_str) "->"

    Str.concat "   #" vStr
    |> Str.concat "   |   "
    |> Str.concat dStr
    |> Str.concat "   |     "
    |> Str.concat kmStr
    |> Str.concat "     |    "
    |> Str.concat durStr
    |> Str.concat "    |  "
    |> Str.concat loadStr
    |> Str.concat "  | ["
    |> Str.concat stopsStr
    |> Str.concat "]"

## Format fleet metrics into summary card text
formatMetricsSummary : FleetMetrics -> Str
formatMetricsSummary = \m ->
    km = Num.to_str m.totalDistanceKm
    dur = Num.to_str m.totalDurationHours
    active = Num.to_str m.activeVehicleCount
    carb = Num.to_str m.totalCarbonKg

    Str.concat "Fleet Summary: " active
    |> Str.concat " vehicles deployed, "
    |> Str.concat km
    |> Str.concat " km traveled, "
    |> Str.concat dur
    |> Str.concat " hours elapsed, "
    |> Str.concat carb
    |> Str.concat " kg CO2 emitted"

expect
    r1 = {
        vehicleId: 1,
        depotId: 0,
        customers: [5, 6],
        distance: 12000.0,
        duration: 7200.0,
        load: 18,
        capacityExcess: 0,
        timeLateness: 0.0,
        isFeasible: Bool.true,
    }
    sol = {
        routes: [r1],
        unassigned: [],
        totalDistance: 12000.0,
        totalCost: 100.0,
        isFeasible: Bool.true,
    }
    tbl = formatRouteTable sol
    Str.contains tbl "VEHICLE" && Str.contains tbl "#1"
