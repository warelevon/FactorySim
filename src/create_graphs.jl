## Turn ToDo lists, productDict and job numbers into sources, destinations and weights
# would be good to get a Dict to match vertice/node index with machine and job index
function createNetworkGraph(sim)
    jobs = sim.jobs
    numNodes = 2
    jobIndex = 1
    for j in filter(j -> !j.isFinished,jobs)
        for t in filter(t ->!t.isComplete, j.tasks)
            numNodes +=1
        end
    end
    nodes = Vector{OptimNode}(numNodes)
    g = simple_inclist(numNodes)
    nodeInd = 2
    for j in filter(j -> !j.isFinished,jobs)
        for t in filter(t ->!t.isComplete, j.tasks)
            nodes[nodeInd].index = nodeInd
            node.machineTypeIndex = Int(t.machineType)
            node.jobIndex = j.index
        end
    end

    eweights1 = zeros(ne)
    for i = 1 : ne
        Graphs.add_edge!(g, sources[i], destinations[i])
        eweights1[i] = weights[i]
    end
    return g, eweights1
end
