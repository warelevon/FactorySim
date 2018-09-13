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
const startLoc = Location(0,0)


@enum MachineType nullMachineType=0 robot=1 workStation=2

@enum ProductType nullProductType=0 chair=1 table=2

@enum EventType nullEvent taskReleased checkAssign assignClosestAvailableWorker moveToJob arriveAtJob moveJobToMachine startMachineProcess releaseWorker finishTask
