"""Data models for Dray fleet routing and optimization."""

from dataclasses import dataclass, field
from typing import List, Optional

@dataclass
class Coord:
    x: float
    y: float

@dataclass
class TimeWindow:
    ready: float
    due: float

@dataclass
class Customer:
    id: int
    coord: Coord
    demand: int
    window: TimeWindow
    service_duration: float

@dataclass
class Depot:
    id: int
    coord: Coord
    window: TimeWindow

@dataclass
class Vehicle:
    id: int
    capacity: int
    depot_id: int
    earliest_start: float
    latest_end: float
    fixed_cost: float = 50.0
    distance_cost_per_unit: float = 1.0

@dataclass
class Route:
    vehicle_id: int
    depot_id: int
    customers: List[int]
    distance: float
    duration: float
    load: int
    capacity_excess: int
    time_lateness: float
    is_feasible: bool

@dataclass
class Metrics:
    total_distance_km: float
    total_duration_hours: float
    active_vehicle_count: int
    capacity_utilization: float
    total_carbon_kg: float
    average_wait_time_sec: float
    unassigned_count: int

@dataclass
class Solution:
    routes: List[Route] = field(default_factory=list)
    unassigned: List[int] = field(default_factory=list)
    total_distance: float = 0.0
    total_cost: float = 0.0
    is_feasible: bool = True
    metrics: Optional[Metrics] = None

@dataclass
class Problem:
    depots: List[Depot]
    customers: List[Customer]
    fleet: List[Vehicle]
    distances: Optional[List[float]] = None
    travel_times: Optional[List[float]] = None
