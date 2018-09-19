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

# create a vector with the index corresponding to a node and the values being a machine or job index
toDo = transpose([1 2 4 0;1 2 3 4;1 2 3 4]) # hard coded matrix of a to do list for 3 jobs
(x,y) = size(toDo)
jobNumber = zeros(y,x)
for i = 1:y
    jobNumber[i,:] = i
end
toDo = vec(reshape(toDo,1,length(toDo)))
jobNumber = vec(reshape(jobNumber,1,length(jobNumber)))

#remove the zero values
r = find(toDo1 -> toDo1 == 0, toDo1)
# remove the indices of any zero values in both arrays
for i = 1:length(r)
    toDo1 = deleteat!(toDo1,r[i])
    jobNumber = deleteat!(jobNumber,r[i])
end
rootElt = xmlFileRoot("C:\\Users\\dd\\.julia\\v0.6\\FactorySim\\example\\sim_config.xml") #hard coded for now
simElt = findElt(rootElt, "sim")
n = parse(Int, eltContent(simElt, "numMachines"))
m = collect(1:n)
nNodes = sum(mJCR)

# create OptimNode types to match the node index with the machine and job index
optimNode = Vector{OptimNode}(nNodes)
optimNode[1] = OptimNode()
optimNode[1].index = 1
optimNode[1].i = nullIndex
optimNode[1].j = nullIndex
optimNode[nNodes] = OptimNode()
optimNode[nNodes].index = nNodes
optimNode[nNodes].i = nullIndex
optimNode[nNodes].j = nullIndex
for i = 2:nNodes+1
    optimNode[i] = OptimNode()
    optimNode[i].index = i
    optimNode[i].i = toDo1[i]
    optimNode[i].j = jobNumber[i]
end
optimNode



# Create a graph of the conjunctive arcs only
(gc, eweights1) = createNetworkGraph(sourcesC,destinationsC,weightsC)

######################### will go in shifting_bottleneck.jl function
#inputs gc, eweights1, nJpbs
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

dijkstra_shortest_paths(gc,-eweights1,1)

#iterate through machines in the set m-m0
for i=1:length(m)-length(m0)
    mDash = filter!(m->m≠a,m) #removes the machine m0
    # generate the 1|rj|Lmax schedule for each machine in mDash
    #cols - mDash[i]
    #rows rj; pij; dj
    for j=1:nJobs
        r = zeros(3)
        r[j] =
    end
end

####### STEP 3:
