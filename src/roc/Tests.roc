module [
    runAllTests,
]

import PriorityQueue
import Graph
import Dijkstra
import KdTree
import Contraction
import Problem
import Solution
import Construction
import DestroyOperators
import RepairOperators
import LocalSearch
import Alns
import DynamicDispatch
import Metrics
import Engine

## Master test runner entry point
runAllTests : {} -> Bool
runAllTests = \{} ->
    testResult =
        testPriorityQueueOrdering {}
        && testGraphConstruction {}
        && testDijkstraShortestPath {}
        && testBidirectionalDijkstra {}
        && testKdTreeSpatialLookup {}
        && testContractionHierarchies {}
        && testProblemCreation {}
        && testSolutionFeasibilityCheck {}
        && testClarkeWrightSavings {}
        && testNearestAdditionHeuristic {}
        && testWorstCostRemoval {}
        && testShawRemovalOperator {}
        && testRouteRemovalOperator {}
        && testGreedyRepairOperator {}
        && testRegret2RepairOperator {}
        && testRegret3RepairOperator {}
        && testTwoOptIntraOptimization {}
        && testRelocateInterOptimization {}
        && testTwoOptStarTailSwap {}
        && testAlnsOptimizationConvergence {}
        && testDynamicOrderInsertion {}
        && testFleetMetricsCalculation {}
        && testEnginePipelineExecution {}

    testResult

testPriorityQueueOrdering : {} -> Bool
testPriorityQueueOrdering = \{} ->
    pq =
        PriorityQueue.empty {}
        |> (\q -> PriorityQueue.insert "c" 30.0 q)
        |> (\q -> PriorityQueue.insert "a" 10.0 q)
        |> (\q -> PriorityQueue.insert "b" 20.0 q)

    when PriorityQueue.popMin pq is
        Ok { item: i1, queue: q1 } ->
            when PriorityQueue.popMin q1 is
                Ok { item: i2, queue: q2 } ->
                    when PriorityQueue.popMin q2 is
                        Ok { item: i3 } ->
                            i1.value == "a" && i2.value == "b" && i3.value == "c"

                        Err _ -> Bool.false

                Err _ -> Bool.false

        Err _ -> Bool.false

testGraphConstruction : {} -> Bool
testGraphConstruction = \{} ->
    g =
        Graph.withNodes 5
        |> (\g0 -> Graph.addBidirectionalEdge g0 0 1 10.0 10.0)
        |> (\g0 -> Graph.addBidirectionalEdge g0 1 2 20.0 20.0)
        |> (\g0 -> Graph.addEdge g0 2 3 5.0 5.0 Bool.false 0)

    Graph.nodeCount g == 5 && Graph.edgeCount g == 5

testDijkstraShortestPath : {} -> Bool
testDijkstraShortestPath = \{} ->
    g =
        Graph.withNodes 4
        |> (\g0 -> Graph.addEdge g0 0 1 1.0 1.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 1 2 2.0 2.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 2 3 3.0 3.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 0 3 10.0 10.0 Bool.false 0)

    when Dijkstra.shortestPath g 0 3 is
        Ok { distance, path } ->
            Num.is_approx_eq distance 6.0 { atol: 0.001 } && path == [0, 1, 2, 3]

        Err _ -> Bool.false

testBidirectionalDijkstra : {} -> Bool
testBidirectionalDijkstra = \{} ->
    g =
        Graph.withNodes 4
        |> (\g0 -> Graph.addEdge g0 0 1 10.0 10.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 1 2 10.0 10.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 2 3 10.0 10.0 Bool.false 0)
        |> (\g0 -> Graph.addEdge g0 0 3 50.0 50.0 Bool.false 0)

    when Dijkstra.bidirectionalSearch g 0 3 is
        Ok d -> Num.is_approx_eq d 30.0 { atol: 0.001 }
        Err _ -> Bool.false

testKdTreeSpatialLookup : {} -> Bool
testKdTreeSpatialLookup = \{} ->
    pts = [
        { id: 1, x: 0.0, y: 0.0 },
        { id: 2, x: 10.0, y: 10.0 },
        { id: 3, x: 100.0, y: 100.0 },
    ]
    tree = KdTree.build pts
    when KdTree.nearestNeighbor tree 8.0 9.0 is
        Ok nearest -> nearest.id == 2
        Err _ -> Bool.false

testContractionHierarchies : {} -> Bool
testContractionHierarchies = \{} ->
    g =
        Graph.withNodes 4
        |> (\g0 -> Graph.addBidirectionalEdge g0 0 1 2.0 2.0)
        |> (\g0 -> Graph.addBidirectionalEdge g0 1 2 3.0 3.0)
        |> (\g0 -> Graph.addBidirectionalEdge g0 2 3 4.0 4.0)

    ch = Contraction.contractGraph g
    when Contraction.chQuery ch 0 3 is
        Ok { distance } -> Num.is_approx_eq distance 9.0 { atol: 0.001 }
        Err _ -> Bool.false

testProblemCreation : {} -> Bool
testProblemCreation = \{} ->
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 1.0, y: 1.0 }, demand: 5, window: { ready: 0.0, due: 500.0 }, serviceDuration: 10.0 }
    v1 = { id: 1, capacity: 50, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 100.0, distanceCostPerUnit: 1.0 }
    mat = {
        dimension: 2,
        distances: [0.0, 1.414, 1.414, 0.0],
        travelTimes: [0.0, 2.0, 2.0, 0.0],
    }
    prob = Problem.createProblem [d0] [c1] [v1] mat
    Problem.customerCount prob == 1 && Problem.totalDemand prob == 5

testSolutionFeasibilityCheck : {} -> Bool
testSolutionFeasibilityCheck = \{} ->
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 15, window: { ready: 0.0, due: 500.0 }, serviceDuration: 10.0 }
    v1 = { id: 1, capacity: 10, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 100.0, distanceCostPerUnit: 1.0 }
    mat = {
        dimension: 2,
        distances: [0.0, 5.0, 5.0, 0.0],
        travelTimes: [0.0, 5.0, 5.0, 0.0],
    }
    prob = Problem.createProblem [d0] [c1] [v1] mat
    r = Solution.evaluateRoute prob v1 [1]
    # Capacity is 10, demand is 15 -> capacityExcess should be 5 and isFeasible false
    r.capacityExcess == 5 && r.isFeasible == Bool.false

testClarkeWrightSavings : {} -> Bool
testClarkeWrightSavings = \{} ->
    prob = createSampleProblem {}
    sol = Construction.clarkeWrightSavings prob
    sol.isFeasible

testNearestAdditionHeuristic : {} -> Bool
testNearestAdditionHeuristic = \{} ->
    prob = createSampleProblem {}
    sol = Construction.nearestAddition prob
    sol.isFeasible

testWorstCostRemoval : {} -> Bool
testWorstCostRemoval = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 2, 3]] []
    res = DestroyOperators.worstCostRemoval prob sol 1
    List.len res.removed == 1

testShawRemovalOperator : {} -> Bool
testShawRemovalOperator = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 2, 3]] []
    res = DestroyOperators.shawRemoval prob sol 1 1
    List.len res.removed == 1

testRouteRemovalOperator : {} -> Bool
testRouteRemovalOperator = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 2], [3]] []
    res = DestroyOperators.routeRemoval sol 0
    List.len res.removed == 2

testGreedyRepairOperator : {} -> Bool
testGreedyRepairOperator = \{} ->
    prob = createSampleProblem {}
    sol = RepairOperators.greedyRepair prob [[1]] [2, 3]
    sol.isFeasible && List.is_empty sol.unassigned

testRegret2RepairOperator : {} -> Bool
testRegret2RepairOperator = \{} ->
    prob = createSampleProblem {}
    sol = RepairOperators.regret2Repair prob [[1]] [2, 3]
    sol.isFeasible && List.is_empty sol.unassigned

testRegret3RepairOperator : {} -> Bool
testRegret3RepairOperator = \{} ->
    prob = createSampleProblem {}
    sol = RepairOperators.regret3Repair prob [[1]] [2, 3]
    sol.isFeasible && List.is_empty sol.unassigned

testTwoOptIntraOptimization : {} -> Bool
testTwoOptIntraOptimization = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 3, 2]] []
    improved = LocalSearch.twoOptIntra prob sol
    improved.totalDistance <= sol.totalDistance

testRelocateInterOptimization : {} -> Bool
testRelocateInterOptimization = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 2], [3]] []
    improved = LocalSearch.relocateMove prob sol
    improved.isFeasible

testTwoOptStarTailSwap : {} -> Bool
testTwoOptStarTailSwap = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 2], [3]] []
    improved = LocalSearch.twoOptStarMove prob sol
    improved.isFeasible

testAlnsOptimizationConvergence : {} -> Bool
testAlnsOptimizationConvergence = \{} ->
    prob = createSampleProblem {}
    cfg = {
        maxIterations: 10,
        startTemperature: 50.0,
        coolingRate: 0.95,
        segmentSize: 5,
        decayRate: 0.8,
        minDestroy: 1,
        maxDestroy: 2,
    }
    sol = Alns.solveAlns prob cfg 777
    sol.isFeasible

testDynamicOrderInsertion : {} -> Bool
testDynamicOrderInsertion = \{} ->
    prob = createSampleProblem {}
    status = {
        currentSimTime: 10.0,
        completedStops: [[]],
        pendingStops: [[1, 2]],
    }
    newCust = {
        id: 3,
        coord: { x: 15.0, y: 0.0 },
        demand: 2,
        window: { ready: 0.0, due: 500.0 },
        serviceDuration: 5.0,
    }
    order = {
        orderId: 99,
        customer: newCust,
        receivedTime: 15.0,
        isUrgent: Bool.true,
    }
    when DynamicDispatch.insertUrgentOrder prob status order is
        Ok updated -> List.len (List.join updated.pendingStops) == 3
        Err _ -> Bool.false

testFleetMetricsCalculation : {} -> Bool
testFleetMetricsCalculation = \{} ->
    prob = createSampleProblem {}
    sol = Solution.evaluateSolution prob [[1, 2, 3]] []
    metrics = Metrics.computeFleetMetrics prob sol
    metrics.totalDistanceKm > 0.0 && metrics.activeVehicleCount == 1

testEnginePipelineExecution : {} -> Bool
testEnginePipelineExecution = \{} ->
    prob = createSampleProblem {}
    sol = Engine.quickSolve prob
    sol.isFeasible

createSampleProblem : {} -> Problem.Problem
createSampleProblem = \{} ->
    d0 = { id: 0, coord: { x: 0.0, y: 0.0 }, window: { ready: 0.0, due: 1000.0 } }
    c1 = { id: 1, coord: { x: 5.0, y: 0.0 }, demand: 3, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c2 = { id: 2, coord: { x: 10.0, y: 0.0 }, demand: 4, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }
    c3 = { id: 3, coord: { x: 15.0, y: 0.0 }, demand: 2, window: { ready: 0.0, due: 500.0 }, serviceDuration: 5.0 }

    v1 = { id: 1, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }
    v2 = { id: 2, capacity: 20, depotId: 0, earliestStart: 0.0, latestEnd: 1000.0, fixedCost: 50.0, distanceCostPerUnit: 1.0 }

    mat = {
        dimension: 4,
        distances: [
            0.0, 5.0, 10.0, 15.0,
            5.0, 0.0, 5.0, 10.0,
            10.0, 5.0, 0.0, 5.0,
            15.0, 10.0, 5.0, 0.0,
        ],
        travelTimes: [
            0.0, 5.0, 10.0, 15.0,
            5.0, 0.0, 5.0, 10.0,
            10.0, 5.0, 0.0, 5.0,
            15.0, 10.0, 5.0, 0.0,
        ],
    }

    Problem.createProblem [d0] [c1, c2, c3] [v1, v2] mat

expect
    runAllTests {} == Bool.true
