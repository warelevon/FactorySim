using FactorySim
using JEMSS

path = @__DIR__


# generate artificial simulation productOrder files
#println("\n=== Generating factory simulation files ===")
#factConfigFilename = joinpath(path, "sim_config.xml")
#runFactConfig(factConfigFilename; overwriteInputPath = true)

# create and run simulation using generated files
println("\n=== Simulating with generated files ===")
simConfigFilename = joinpath(path, "sim_config.xml")
sim = initSimulation(simConfigFilename; allowWriteOutput = true)
openOutputFiles!(sim)
simulate!(sim)
closeOutputFiles!(sim)
sim.numCompletedTasks
sim.numCompletedJobs


println("\n=== Resimulating based on output/events file ===")
sim = initSimulation(simConfigFilename)
simulate!(sim)
animate(port = 8001, configFilename = simConfigFilename)

testshed = eddTaskOrder(sim.jobs).factoryTaskList
testshed = (sort!(testshed, by=t->t.machineProcessStart) .|> t->t.jobIndex)


using FactorySim
using JEMSS

path = @__DIR__


# generate artificial simulation productOrder files
#println("\n=== Generating factory simulation files ===")
#factConfigFilename = joinpath(path, "sim_config.xml")
#runFactConfig(factConfigFilename; overwriteInputPath = true)

# create and run simulation using generated files
println("\n=== Simulating with generated files ===")
simConfigFilename = joinpath(path, "sim_config.xml")
sim = initSimulation(simConfigFilename)
sim.useSchedule = true
shed = Schedule()
shed = eddTaskOrder(sim.jobs)
tasks = shed.factoryTaskList
numTasks = length(tasks)
jobInds = (tasks .|> (t->t.jobIndex))
sim.schedule = jobInds
simulate!(sim)

using FactorySim
using JEMSS

path = @__DIR__


# generate artificial simulation productOrder files
#println("\n=== Generating factory simulation files ===")
#factConfigFilename = joinpath(path, "sim_config.xml")
#runFactConfig(factConfigFilename; overwriteInputPath = true)

# create and run simulation using generated files
println("\n=== Simulating with generated files ===")
simConfigFilename = joinpath(path, "sim_config.xml")
sim = initSimulation(simConfigFilename)
sim.useSchedule = true
shed = Schedule()
shed = erdTaskOrder(sim.jobs)
tasks = shed.factoryTaskList
numTasks = length(tasks)
jobInds = (tasks .|> (t->t.jobIndex))
sim.schedule = jobInds
simulate!(sim)


rjob = jobInds[randperm(numTasks)]
simtimes = zeros(100)
simcompletes = zeros(100)
simperms = Vector{Vector{}}(100)
for i = 1:100
    sim = initSimulation(simConfigFilename)
    sim.useSchedule = true
    sim.schedule = jobInds[randperm(numTasks)]
    simperms[i] = Vector(numTasks)
    simperms[i] = deepcopy(sim.schedule)
    simulate!(sim)
    simtimes[i] = sim.time-sim.startTime
    simcompletes[i] = sim.numCompletedTasks
    if i in 1:10:100; println("                                                                               ",i); end
end
minimum(simcompletes)
simperms
simcompletes
minimum(simtimes)
sim.time-sim.startTime


sim.machines[1].batchedJobIndeces
isFreeMachine(sim,robot)
FactorySim.batchCheckStart(sim,sim.machines[1])
sim.jobs[2].status
sim.schedule
