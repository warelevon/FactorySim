__precompile__()
module FactorySim

importall JEMSS

# animation
using HttpServer
using WebSockets
using JSON

# files
using LightXML

# optimisation (move-up)
using JuMP
using GLPKMathProgInterface # does not use precompile

# statistics
using Distributions
using HypothesisTests
using Stats
using StatsFuns

# misc
using LightGraphs
using ArchGDAL # does not use precompile
using JLD
import Plots

export
    runFactConfig, makeFactoryArcs, makeFactoryNodes, readLocationsFile, fact_animate

export
    decomposeOrder, eddTaskOrder, checkFreeWorker!, findClosestWorker, freeMachines, isFreeMachine, findClosestMachine, simulateEvent!

export # file_io functions
    readOrderListFile, readMachinesFile, readWorkersFile

export
    FactoryTask, Job, Schedule, ProductOrder, Worker, Machine, Event, Simulation

export
    MachineType, nullMachineType, workStation, robot,
    ProductType, nullProductType, chair, table,
    startingLoc


include("defs.jl")

include("types/types.jl")
include("file_io/read_in_files.jl")
include("types/order.jl")

include("animation/fact_animation.jl")

include("gen_fact_sim_files.jl")
include("simulation.jl")


end
