## This is currently a testing script. The plan is to move functions to src files
using JEMSS, FactorySim, Distributions, Graphs

# test graph inputs for conjunctive and disjunctive graphs
sourcesC = [1,2,3,4,1,5,6,7,8,1,9,10,11,12]
destinationsC = [2,3,4,13,5,6,7,8,13,9,10,11,12,13]
weightsC = -[0.,21.,10.,6.,0.,21.,10.,6.,4.,0.,21.,10.,6.,4.] # To create a solution related to our assumptions
sourcesD1 = [2,2,5,5,9,9]
destinationsD1 = [5,9,2,9,2,5]
weightsD1 = [0.,0.,0.,0.,0.,0.]
sourcesD2 = [3,3,6,6,10,10]
destinationsD2 = [6,10,3,10,3,6]
weightsD2 = [10.,10.,10.,10.,10.,10.]
sourcesD3 = [7,11]
destinationsD3 = [11,7]
weightsD3 = [6.,6.]
sourcesD4 = [4,4,8,8,12,12]
destinationsD4 = [8,12,4,12,4,8]
weightsD4 = [6.,6.,4.,4.,4.,4.]

# Create a graph of the conjunctive arcs only
gc = createNetworkGraph(sourcesC,destinationsC,weightsC)

######################### will go in shifting_bottleneck.jl function
## STEP 0:
# Set variables
rootElt = xmlFileRoot("C:\\Users\\dd\\.julia\\v0.6\\FactorySim\\example\\sim_config.xml") #hard coded for now
simElt = findElt(rootElt, "sim")
n = parse(Int, eltContent(simElt, "numMachines"))
m = collect(1:n)

####### STEP 1:
# Set  M_0
m0 = Int64[]
# Find Cmax for the graph with only conjuctive arcs, no disjunctive arcs
s1 = Graphs.bellman_ford_shortest_paths(gc, eweights1, [1])
cMax = maximum(-s1.dists)
length(m0)

####### STEP 2:
# Used for the filter() function in step 2
if length(m0)==0
    a = 0
else
    a = m0[1]
end
@assert isinteger(a) && a>=0
#iterate through machines in the set m-m0
for i=1:length(m)-length(m0)
    mDash = filter!(m->m≠a,m)
    println("machines evaluated are: ",mDash)

end
####### STEP 3:
