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
    readFactConfig, runFactConfig, makeFactoryArcs, makeFactoryNodes, readLocationsFile, fact_animate, makeOrders

export
    writeOrdersFile

export
    decomposeOrder, eddTaskOrder, checkFreeWorker!, findClosestWorker, freeMachines, isFreeMachine, findClosestMachine, simulateFactoryEvent!

export
    resetSim!, simulate!, backupSim!

export # file_io functions
    readOrderListFile, readMachinesFile, readWorkersFile, openOutputFiles!, writeEventToFile!, closeOutputFiles!, readProductOrdersFile

export
    FactoryTask, Job, Schedule, ProductOrder, Worker, Machine, Event, Resimulation, Simulation

export
    MachineType, nullMachineType, workStation, robot,
    ProductType, nullProductType, chair, table,
    EventType, nullEvent, taskReleased, checkAssign, assignClosestAvailableWorker, moveToJob, arriveAtJob, moveJobToMachine, startMachineProcess, releaseWorker, finishTask,
    WorkerStatus, nullWorkerStatus, workerIdle, workerMovingToJob, workerAtJob, workerMovingToMachine, workerProcessingJob,
    JobStatus, nullJobStatus, jobQueued, jobWaitingForWorker, jobGoingToMachine, jobAtMachine, jobProcessed,
    startingLoc


include("defs.jl")

include("types/types.jl")
include("file_io/read_in_files.jl")
include("file_io/write_files.jl")
include("write_sim_files.jl")
include("types/order.jl")

include("animation/fact_animation.jl")

include("gen_fact_sim_files.jl")
include("JEMSSImport.jl")
include("simulation.jl")


end
