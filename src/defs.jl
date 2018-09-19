# common definitions


const sourcePath = @__DIR__


# run modes
const debugMode = false
const checkMode = true # for data checking, e.g. assertions that are checked frequently

# file chars
const delimiter = ','
const newline = "\r\n"

# misc null values
nullFunction() = nothing

const nullTime = -1.0
const nullDist = -1.0


@enum MachineType nullMachineType=0 robot=1 assembleBench=2 paintBench=3 boxing=4

@enum ProductType nullProductType=0 chair=1 table=2

@enum EventType nullEvent taskReleased checkAssign assignClosestAvailableWorker moveToJob arriveAtJob moveJobToMachine startMachineProcess releaseWorker finishTask finishAndRelease finishBatch

@enum WorkerStatus nullWorkerStatus workerIdle workerMovingToJob workerAtJob workerMovingToMachine workerProcessingJob

@enum JobStatus nullJobStatus jobQueued jobWaitingForWorker jobGoingToMachine jobAtMachine jobProcessed jobBatched
