## Turn ToDo lists, productDict and job numbers into sources, destinations and weights
# would be good to get a Dict to match vertice/node index with machine and job index
function createNetworkGraph(sim)
    jobs = sim.jobs
    numNodes = 2
    numJobs = 0
    maxNumTasks = 0
    for j in filter(j -> !j.finished,jobs)
        numJobs+=1
        numTasks=0
        filteredTasks = filter(t ->!t.isComplete, j.tasks)
        if !(j.status==nullJobstatus || j.status == jobQueued)
            shift!(filteredTasks)
        end
        for t in filteredTasks
            numNodes +=1
            numTasks+=1
        end
        maxNumTasks = max(maxNumTasks,numTasks)
    end
    nodes = Vector{OptimNode}(numNodes)
    g = simple_inclist(numNodes)
    nodeInd = 2
    nodes[1] = OptimNode()
    nodes[1].index = 1
    nodeLookup = zeros(Integer,numJobs,maxNumTasks)
    for j in filter(j -> !j.finished,jobs)
        filteredTasks = filter(t ->!t.isComplete, j.tasks)
        if !(j.status==nullJobstatus || j.status == jobQueued)
            shift!(filteredTasks)
        end
        for t in filteredTasks
            nodes[nodeInd] = OptimNode()
            node = nodes[nodeInd]
            node.index = nodeInd
            node.machineTypeIndex = Int(t.machineType)
            node.jobIndex = j.index
            nodeLookup[node.jobIndex,node.machineTypeIndex] = node.index
            nodeInd+=1
        end
    end
    nodes[numNodes] = OptimNode()
    nodes[numNodes].index = numNodes
    jobtypes = sort(unique(nodes[2:end-1] .|> [x->x.jobIndex]))
    ne=0
    for j in jobtypes
        mactypes = sort(filter(n->n.jobIndex==j,nodes[2:end-1]) .|> [x->x.machineTypeIndex])
        for m in mactypes
            node = nodes[nodeLookup[j,m]]
            if m == mactypes[1]
                Graphs.add_edge!(g,1,node.index)
                ne+=1
            end
            if m == mactypes[end]
                Graphs.add_edge!(g,node.index,numNodes)
                ne+=1
            else
                Graphs.add_edge!(g,node.index,nodeLookup[j,findfirst(mactypes.>m)])
                ne+=1
            end
            for m2 in mactypes
                if (m!=m2&&nodeLookup[j,m2]>0)
                    Graphs.add_edge!(g,node.index,nodeLookup[j,m2])
                    ne+=1
                end
            end
        end
    end
    return g
end

function createNetworkGraph(sources,destinations,weights)
    ne = length(sources)
    g = simple_inclist(ne)
    eweights1 = zeros(ne)
    for i = 1 : ne
        Graphs.add_edge!(g, sources[i], destinations[i])
        eweights1[i] = weights[i]
    end
    return g, eweights1
end
