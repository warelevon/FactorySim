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

sim

println("\n=== Resimulating based on output/events file ===")
sim = initSimulation(simConfigFilename)
animate(port = 8001, configFilename = simConfigFilename)

# Stats and output used for report/talks/compendium
utilisation = getUtilisation(sim) #for workers
