using FactorySim
using JEMSS

path = @__DIR__


# generate artificial simulation productOrder files
println("\n=== Generating factory simulation files ===")
factConfigFilename = joinpath(path, "sim_config.xml")
runFactConfig(factConfigFilename; overwriteOutputPath = true)

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
