## Turn ToDo lists, productDict and job numbers into sources, destinations and weights
# would be good to get a Dict to match vertice/node index with machine and job index
function createNetworkGraphInput()

    return
end

# create a directed Graph relating to a snapshot of the problem
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
