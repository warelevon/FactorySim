## This is currently a testing script. The plan is to move functions to src files
using JEMSS, FactorySim, Graphs

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

# misc input
nJobs = 3 # hard coded for now
nNodes = maximum(destinationsC) #nodes
n = 4 # machines
# create a vector with the index corresponding to a node and the values being a machine or job index
toDo = transpose([1 2 4 0;1 2 3 4;1 2 3 4]) # hard coded matrix of a to do list for 3 jobs
(x,y) = size(toDo)
jobNumber = zeros(y,x)
for i = 1:y
    jobNumber[i,:] = i
end
toDo1 = vec(reshape(toDo,1,length(toDo)))
jobNumber = vec(reshape(transpose(jobNumber),1,length(jobNumber)))
#remove the zero values
r = find(toDo1 -> toDo1 == 0, toDo1)
# remove the indices of any zero values in both arrays
for i = 1:length(r)
    toDo1 = deleteat!(toDo1,r[i])
    jobNumber = deleteat!(jobNumber,r[i])
end

# create OptimNode types to match the node index with the machine and job index
optimNodes = Vector{OptimNode}(nNodes)
optimNodes[1] = OptimNode()
optimNodes[1].index = 1
optimNodes[1].machineTypeIndex = nullIndex
optimNodes[1].jobIndex = nullIndex
optimNodes[nNodes] = OptimNode()
optimNodes[nNodes].index = nNodes
optimNodes[nNodes].machineTypeIndex = nullIndex
optimNodes[nNodes].jobIndex = nullIndex
for i = 2:nNodes-1
    optimNodes[i] = OptimNode()
    optimNodes[i].index = i
    optimNodes[i].machineTypeIndex = toDo1[i-1]
    optimNodes[i].jobIndex = jobNumber[i-1]
end
optimNodes

# Create an optimArcType
numArcs = length(weightsC)
optimArcs = Vector{OptimArc}(numArcs)
for i = 1:numArcs
    optimArcs[i] = OptimArc()
    optimArcs[i].index = i
    optimArcs[i].weight = weightsC[i]
    optimArcs[i].sourceNode = sourcesC[i]
    optimArcs[i].destinationNode = destinationsC[i]
end

# Create a graph of the conjunctive arcs only
(gc, eweights1) = createNetworkGraph(sourcesC,destinationsC,weightsC)

######################### will go in shifting_bottleneck.jl function
#inputs gc, eweights1, nJobs, simFilepath?
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

####### STEP 2:
# Used for the filter() function in step 2
if length(m0)==0
    a = 0
else
    a = m0[1]
end
@assert isinteger(a) && a>=0

# Find the distances from the source node to all other nodes in graph
r = dijkstra_shortest_paths(gc,-eweights1,1)
#iterate through machines in the set m-m0
for i=1:length(m)-length(m0)
    mDash = filter!(m->m≠a,m) #removes the machine m0
    miNodes = filter(n -> n.machineTypeIndex==1,optimNodes) #get the node index of machine 1 operations
    # generate the 1|rj|Lmax schedule for each machine in mDash
    #cols - mDash[i]
    #rows rj; pij; dj
    for j=1:length(miNodes)
        r = zeros(length(miNodes))
        r[j] = r.dists[miNodes[j]] #releaseTime of job j at machine i
        #miWeight = filter(n -> n.sourceNode==j,optimArcs)[1]
        p[j] = filter(n -> n.sourceNode==j,optimArcs)[1] #processing time of  job j at machine i
    end
end

####### STEP 3:
