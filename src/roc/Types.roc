module [
    Coord,
    Distance,
    Time,
    Demand,
    NodeId,
    VehicleId,
    TimeWindow,
    Location,
    Stop,
    VehicleProfile,
    distanceEuclidean,
    isTimeFeasible,
]

## Coordinate in a local projected cartesian grid (meters or kilometers)
Coord : {
    x : F64,
    y : F64,
}

## Distance in meters
Distance : F64

## Time in seconds from midnight or start of planning horizon
Time : F64

## Quantity of cargo units demanded or carried
Demand : I64

## Unique identifier for a customer or depot node
NodeId : U64

## Unique identifier for a vehicle in the fleet
VehicleId : U64

## Allowed service window: arrival before ready means waiting; arrival after due is infeasible
TimeWindow : {
    ready : Time,
    due : Time,
}

## A physical location with geographical coordinates and an identifier
Location : {
    id : NodeId,
    coord : Coord,
    demand : Demand,
    window : TimeWindow,
    serviceTime : Time,
}

## A scheduled stop in a vehicle itinerary
Stop : {
    locationId : NodeId,
    arrivalTime : Time,
    departureTime : Time,
    loadAfter : Demand,
}

## Operational characteristics and physical constraints of a vehicle
VehicleProfile : {
    id : VehicleId,
    capacity : Demand,
    depotId : NodeId,
    earliestStart : Time,
    latestEnd : Time,
    fixedCost : F64,
    distanceCostPerUnit : F64,
}

## Calculate straight line Euclidean distance between two cartesian coordinates
distanceEuclidean : Coord, Coord -> Distance
distanceEuclidean = \c1, c2 ->
    dx = c1.x - c2.x
    dy = c1.y - c2.y
    Num.sqrt (dx * dx + dy * dy)

## Check whether an arrival time falls within the allowed time window
isTimeFeasible : Time, TimeWindow -> Bool
isTimeFeasible = \arrival, window ->
    arrival <= window.due

expect
    c1 = { x: 0.0, y: 0.0 }
    c2 = { x: 3.0, y: 4.0 }
    d = distanceEuclidean c1 c2
    d > 4.99 && d < 5.01

expect
    tw = { ready: 100.0, due: 200.0 }
    isTimeFeasible 150.0 tw == Bool.true

expect
    tw = { ready: 100.0, due: 200.0 }
    isTimeFeasible 201.0 tw == Bool.false
