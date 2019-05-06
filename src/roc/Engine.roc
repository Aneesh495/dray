module [
    EngineRequest,
    EngineResponse,
    runOptimizationEngine,
    quickSolve,
]

import Problem exposing [Problem]
import Solution exposing [Solution]
import Alns exposing [AlnsConfig, defaultConfig, solveAlns]
import Metrics exposing [FleetMetrics, computeFleetMetrics]
import LocalSearch exposing [runLocalSearch]

EngineRequest : {
    problem : Problem,
    config : AlnsConfig,
    seed : U64,
}

EngineResponse : {
    solution : Solution,
    metrics : FleetMetrics,
    iterationsRun : U64,
    executionTimeMs : F64,
}

## Run full Dray optimization pipeline: initial seeding, ALNS metaheuristics, and local search polishing
runOptimizationEngine : EngineRequest -> EngineResponse
runOptimizationEngine = \req ->
    rawBest = solveAlns req.problem req.config req.seed
    polished = runLocalSearch req.problem rawBest 10
    metrics = computeFleetMetrics req.problem polished

    {
        solution: polished,
        metrics,
        iterationsRun: req.config.maxIterations,
        executionTimeMs: 0.0,
    }

## Quick solve with default settings
quickSolve : Problem -> Solution
quickSolve = \problem ->
    req = {
        problem,
        config: defaultConfig,
        seed: 42,
    }
    resp = runOptimizationEngine req
    resp.solution

expect
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c2 = { id: 2, coord: { x: 10.0, y: 0.0 }, demand: 4, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 3,
        distances: [0.0, 5.0, 10.0, 5.0, 0.0, 5.0, 10.0, 5.0, 0.0],
        travelTimes: [0.0, 5.0, 10.0, 5.0, 0.0, 5.0, 10.0, 5.0, 0.0],
    }

    prob = Problem.createProblem [d0] [c1, c2] [v1] mat

    req = {
        problem: prob,
        config: {
            maxIterations: 5,
            startTemperature: 10.0,
            coolingRate: 0.9,
            segmentSize: 5,
            decayRate: 0.8,
            minDestroy: 1,
            maxDestroy: 2,
        },
        seed: 123,
    }

    resp = runOptimizationEngine req
    resp.solution.isFeasible == Bool.true
