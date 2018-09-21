## This is currently a testing script. The plan is to move functions to src files
using JEMSS, FactorySim, Graphs

# test graph inputs for conjunctive and disjunctive graphs
sourcesC = [1,2,3,4,1,5,6,7,8,1,9,10,11,12]
targetsC = [2,3,4,13,5,6,7,8,13,9,10,11,12,13]
weightsC = [0.,21.,10.,6.,0.,21.,10.,6.,4.,0.,21.,10.,6.,4.] # To create a solution related to our assumptions
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
nNodes = maximum(targetsC) #nodes
n = 4 # machines
dueDates = [40.,40.,30.]
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

# Create an optimArcType
numArcs = length(weightsC)
optimArcs = Vector{OptimArc}(numArcs)
for i = 1:numArcs
    optimArcs[i] = OptimArc()
    optimArcs[i].index = i
    optimArcs[i].weight = weightsC[i]
    optimArcs[i].sourceIndex = sourcesC[i]
    optimArcs[i].targetIndex = targetsC[i]
end

# Create a graph of the conjunctive arcs only
(gc, eweights1) = createNetworkGraph(sourcesC,targetsC,weightsC)

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
path = Graphs.bellman_ford_shortest_paths(gc, -eweights1, [1]) # negative weights
(Graphs.bellman_ford_shortest_paths(gc, eweights1,[2]).dists)[end-1]
# negative weights
path.dists = -path.dists # positive weights
cMax = maximum(path.dists)
maxL = zeros(length(m))
addedScheduleNodeIndex = zeros(0)

####### STEP 2:
# Used for the filter() function in step 2
if length(m0)==0
    a = 0
else
    a = m0[1]
end
@assert isinteger(a) && a>=0
mDash = filter!(m->m≠a,m) #removes the set of scheduled machine(s), m0
#iterate through machines in the set m-m0
pTime = zeros(length(mDash))
lMax = zeros(length(mDash))
subSchedules = Vector{Vector{SubSchedule}}(length(mDash))
sortedSubSchedule = Vector{Integer}(length(mDash))
for i = 1:length(mDash)
    miNodes = filter(n -> n.machineTypeIndex==mDash[i],optimNodes) #get the node index of machine 1 operations
    miNodesIndex = (miNodes .|> [d -> d.index]) # node index at machine i
    subSchedules[i] = Vector{SubSchedule}(length(miNodes))
    subSchedule = subSchedules[i]
    # generate the 1|rj|Lmax schedule for each machine in mDash
    for j=1:length(miNodes)
        subSchedule[j] = SubSchedule()
        n = miNodesIndex[j] # node index, shorthand
        subSchedule[j].nodeIndex = n
        SubSchedule[j].jobIndex = miNodes[j]
        subSchedule[j].releaseTime = path.dists[n] # releaseTime (rj) of job j at machine i
        miWeight = filter(n -> n.sourceIndex==miNodesIndex[j],optimArcs)
        subMiWeight = (miWeight .|> [m -> m.weight])
        subSchedule[j].processingTime = subMiWeight[1] #processing time of  job j at machine i
        # Get the critical path from node j to the sink
        subSchedule[j].cP = Graphs.bellman_ford_shortest_paths(gc, eweights1,[miNodesIndex[j]]).dists[end-1]
        subSchedule[j].dueTime = cMax-subSchedule[j].cP
        #shifted time origin
        subSchedule[j].shiftedDueTime = subSchedule[j].dueTime - subSchedule[j].releaseTime
        @show subSchedule[j].dueTime
    end
    # solve the 1|rj|Lmax schedule for each machine in mDash
    sortedSubSchedule = sort(subSchedule, by= t -> t.shiftedDueTime)
    subSchedules[i] =  sortedSubSchedule

    ##### get the objective value and solution
    for l = 1:length(miNodes)
        pTime[i] += subSchedules[i][l].processingTime
    end
    lMax[i] = pTime[i] - subSchedules[i][end].dueTime
    @show lMax
end

####### STEP 3:
## Schedule the new bottleneck solution in the graph
(lMax,k) = findmax(lMax)
sourceNodesUpdate = zeros(0)
targetNodesUpdate = zeros(0)
weightsUpdate = zeros(0)
# Create vectors to add to the graph through the add edge function
numTasks = length(subSchedules[k])
for i = 1:numTasks-1
    append!(sourceNodesUpdate, subSchedules[k][i].nodeIndex)
    append!(targetNodesUpdate, subSchedules[k][i+1].nodeIndex)
    append!(weightsUpdate, 0.0)
end
assert(length(sourceNodesUpdate)==length(targetNodesUpdate)==length(weightsUpdate))
sourceNodesUpdate
targetNodesUpdate
weightsUpdate
# Add the vectors to a graph

append!(sourcesC,sourceNodesUpdate)
append!(targetsC,targetNodesUpdate)
append!(weightsC,weightsUpdate)
typeof(weightsC)

gNew = createNetworkGraph(sourcesC,targetsC,weightsC)
