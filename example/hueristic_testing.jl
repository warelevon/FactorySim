using FactorySim
using JEMSS

path = @__DIR__

# create and run simulation using generated files
println("\n=== Simulating with generated files ===")
simConfigFilename = joinpath(path, "sim_config.xml")
sim = initSimulation(simConfigFilename; allowWriteOutput = true)
openOutputFiles!(sim)
simulate!(sim)
closeOutputFiles!(sim)
OGsimtime = sim.time-sim.startTime

tasks = deepcopy(sim.tasks)
sort!(tasks, by= (t->t.machineProcessStart))
jobInds = (tasks .|> (t->t.jobIndex))
taskInds = (tasks .|> (t->t.withinJobIndex))

sim = initSimulation(simConfigFilename; allowWriteOutput = true)
sim.useSchedule = true
sim.schedule.jobInds = jobInds
sim.schedule.taskInds = taskInds
openOutputFiles!(sim)
simulate!(sim)
closeOutputFiles!(sim)
numTasks = length(tasks)

simtimes = zeros(100)
simcompletes = zeros(100)
simperms = Vector{Schedule}(100)
utils = zeros(100)
swaps=zeros(Integer,100,2)

for i = 1:100
    sim = initSimulation(simConfigFilename)
    j=rand(1:numTasks)
    k=rand(1:numTasks)
    swaps[i,1] =j
    swaps[i,2] =k
    jobIndex,taskIndex = deepcopy(jobInds),deepcopy(taskInds)
    jobIndex[j],jobIndex[k],taskIndex[j],taskIndex[k]= jobIndex[k],jobIndex[j],taskIndex[k],taskIndex[j]
    sim.useSchedule = true
    sim.schedule.jobInds = jobIndex
    sim.schedule.taskInds = taskIndex
    simperms[i] = Schedule(numTasks)
    simperms[i] = deepcopy(sim.schedule)
    simulate!(sim)
    simtimes[i] = sim.time-sim.startTime
    simcompletes[i] = sim.numCompletedTasks
    utils[i] = getUtilisation(sim)
end
goodI=filter(i->simcompletes[i]>378,collect(1:100))
minimum(simtimes[goodI])

simcompletes
sim.schedule
jobInds
jobIndex
goodperms = (goodI .|> i-> ((simperms[i].jobInds[swaps[i,:]]), simperms[i].taskInds[swaps[i,:]]))

simcompletes[1:10]
utils[goodI]
