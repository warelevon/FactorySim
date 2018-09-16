using FactorySim
using JEMSS

path = @__DIR__


# generate artificial simulation input files
# println("\n=== Generating factory simulation files ===")
# factConfigFilename = joinpath(path, "fact_config.xml")
# runFactConfig(factConfigFilename; overwriteOutputPath = true)

# create and run simulation using generated files
println("\n=== Simulating with generated files ===")
simConfigFilename = joinpath(path, "sim_config.xml")
sim = initSimulation(simConfigFilename; allowWriteOutput = true)
openOutputFiles!(sim)
simulate!(sim)
closeOutputFiles!(sim)
sim.numCompletedTasks
sim.numCompletedJobs
