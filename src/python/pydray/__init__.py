"""Dray Python SDK: High-performance fleet optimization and vehicle routing."""

from .models import Coord, TimeWindow, Customer, Depot, Vehicle, Route, Solution, Metrics
from .client import DrayClient
from .generator import generate_instance

__version__ = "0.1.0"
__all__ = [
    "Coord",
    "TimeWindow",
    "Customer",
    "Depot",
    "Vehicle",
    "Route",
    "Solution",
    "Metrics",
    "DrayClient",
    "generate_instance",
]
