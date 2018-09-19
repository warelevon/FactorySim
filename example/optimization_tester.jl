## This is currently a testing script. The plan is to move functions to src files

using LightGraphs, SimpleWeightedGraphs, Distributions, Graphs

# test graph
sources = [1,2,3,4,5,1,7,8,9,10]
destinations = [2,3,4,5,6,7,8,9,10,6]
# Create a random number generator to come up with example arc weights
randWeights = -rand!(Uniform(10,200),zeros(length(sources))) # minutes (negative for the bellman-ford algorithm)
weights = -[1.,1.,1.,1.,1.,2.,2.,2.,2.,2.] #

ne = length(sources)
g1 = simple_inclist(ne)

eweights1 = zeros(ne)
for i = 1 : ne
    Graphs.add_edge!(g1, sources[i], destinations[i])
    eweights1[i] = weights[i]
end

@assert num_vertices(g1) == max(maximum(sources),maximum(destinations)) #max node index number
@assert num_edges(g1) == 10

# Single Source
typeof(g1)
s1 = Graphs.bellman_ford_shortest_paths(g1, eweights1, [1])
sps = enumerate_paths(graphs.vertices(g1), s1.parent_indices)
