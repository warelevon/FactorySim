## Turn ToDo lists, productDict and job numbers into sources, destinations and weights
function createNetworkGraphInput()

    return
end

# a diGraph relating to a snapshot of the problem
# and a Dict to match vertice/node index with machine and job index
function createNetworkGraph(sources,destinations,weights)
    ne = length(sources)
    g = simple_inclist(ne)
    eweights1 = zeros(ne)
    for i = 1 : ne
        Graphs.add_edge!(g, sources[i], destinations[i])
        eweights1[i] = weights[i]
    end
    return g
end
