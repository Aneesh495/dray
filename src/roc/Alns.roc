module [
    AlnsConfig,
    AlnsState,
    defaultConfig,
    solveAlns,
]

import Problem exposing [Problem]
import Solution exposing [Solution]
import Construction exposing [clarkeWrightSavings, nearestAddition]
import DestroyOperators exposing [randomRemoval, worstCostRemoval, shawRemoval, routeRemoval]
import RepairOperators exposing [greedyRepair, regret2Repair, regret3Repair]
import LocalSearch exposing [runLocalSearch]

AlnsConfig : {
    maxIterations : U64,
    startTemperature : F64,
    coolingRate : F64,
    segmentSize : U64,
    decayRate : F64,
    minDestroy : U64,
    maxDestroy : U64,
}

## Default configuration parameters for ALNS optimization
defaultConfig : AlnsConfig
defaultConfig = {
    maxIterations: 100,
    startTemperature: 100.0,
    coolingRate: 0.98,
    segmentSize: 20,
    decayRate: 0.8,
    minDestroy: 1,
    maxDestroy: 4,
}

OperatorWeights : {
    dRandom : F64,
    dWorst : F64,
    dShaw : F64,
    dRoute : F64,
    rGreedy : F64,
    rRegret2 : F64,
    rRegret3 : F64,
}

AlnsState : {
    iteration : U64,
    currentSolution : Solution,
    bestSolution : Solution,
    temperature : F64,
    weights : OperatorWeights,
    seed : U64,
}

## Execute Adaptive Large Neighborhood Search to optimize VRPTW solution
solveAlns : Problem, AlnsConfig, U64 -> Solution
solveAlns = \problem, config, initialSeed ->
    # Generate initial feasible solution via Clarke-Wright or Nearest Addition
    cwSol = clarkeWrightSavings problem
    initialSol = if cwSol.isFeasible then cwSol else nearestAddition problem

    initWeights = {
        dRandom: 1.0,
        dWorst: 1.0,
        dShaw: 1.0,
        dRoute: 1.0,
        rGreedy: 1.0,
        rRegret2: 1.0,
        rRegret3: 1.0,
    }

    initState = {
        iteration: 0,
        currentSolution: initialSol,
        bestSolution: initialSol,
        temperature: config.startTemperature,
        weights: initWeights,
        seed: initialSeed,
    }

    alnsLoop problem config initState

alnsLoop : Problem, AlnsConfig, AlnsState -> Solution
alnsLoop = \problem, config, state ->
    if state.iteration >= config.maxIterations then
        state.bestSolution
    else
        # Select destroy operator (1=Random, 2=Worst, 3=Shaw, 4=Route)
        (destroyOp, nextSeed1) = pickOperator state.seed 4
        # Select repair operator (1=Greedy, 2=Regret2, 3=Regret3)
        (repairOp, nextSeed2) = pickOperator nextSeed1 3

        # Determine number of customers to remove
        span = if config.maxDestroy > config.minDestroy then config.maxDestroy - config.minDestroy + 1 else 1
        qRemove = config.minDestroy + (nextSeed2 % span)

        # Apply chosen destroy operator
        destResult =
            when destroyOp is
                1 -> randomRemoval state.currentSolution qRemove nextSeed2
                2 -> worstCostRemoval problem state.currentSolution qRemove
                3 ->
                    pivot = when List.first (List.join (List.map state.currentSolution.routes \r -> r.customers)) is
                        Ok id -> id
                        Err _ -> 1
                    shawRemoval problem state.currentSolution qRemove pivot

                _ ->
                    rIdx = nextSeed2 % (Num.max 1 (List.len state.currentSolution.routes))
                    routeRemoval state.currentSolution rIdx

        # Apply chosen repair operator
        repaired =
            when repairOp is
                1 -> greedyRepair problem destResult.routes destResult.removed
                2 -> regret2Repair problem destResult.routes destResult.removed
                _ -> regret3Repair problem destResult.routes destResult.removed

        # Quick local search improvement
        candidate = runLocalSearch problem repaired 5

        # Evaluate candidate against current using Simulated Annealing criterion
        deltaCost = candidate.totalCost - state.currentSolution.totalCost
        (accepted, nextSeed3) =
            if deltaCost < 0.0 then
                (Bool.true, nextSeed2)
            else
                acceptanceProb = Num.pow (2.71828) (-deltaCost / (Num.max 0.001 state.temperature))
                (roll, s3) = pseudoRandomUniform nextSeed2
                (roll < acceptanceProb, s3)

        newCurrent = if accepted then candidate else state.currentSolution
        newBest = if candidate.totalCost < state.bestSolution.totalCost && candidate.isFeasible then candidate else state.bestSolution

        nextState = {
            iteration: state.iteration + 1,
            currentSolution: newCurrent,
            bestSolution: newBest,
            temperature: state.temperature * config.coolingRate,
            weights: state.weights,
            seed: nextSeed3,
        }

        alnsLoop problem config nextState

pickOperator : U64, U64 -> (U64, U64)
pickOperator = \seed, numChoices ->
    nextSeed = (seed * 1103515245 + 12345) % 2147483648
    choice = 1 + (nextSeed % numChoices)
    (choice, nextSeed)

pseudoRandomUniform : U64 -> (F64, U64)
pseudoRandomUniform = \seed ->
    nextSeed = (seed * 1103515245 + 12345) % 2147483648
    frac = (Num.to_f64 nextSeed) / 2147483648.0
    (frac, nextSeed)

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

    config = {
        maxIterations: 5,
        startTemperature: 50.0,
        coolingRate: 0.9,
        segmentSize: 5,
        decayRate: 0.8,
        minDestroy: 1,
        maxDestroy: 2,
    }

    best = solveAlns prob config 999
    best.isFeasible == Bool.true
