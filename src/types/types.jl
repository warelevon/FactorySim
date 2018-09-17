type FactoryTask

    index::Integer
    parentIndex::Integer
    withinJobIndex::Integer
    jobIndex::Integer
    machineType::MachineType

    withWorker::Float
    withoutWorker::Float
    isComplete::Bool
    workerIndex::Integer
    workerArrived::Bool

    machineIndex::Integer

    FactoryTask() = new(nullIndex,nullIndex,nullIndex,nullIndex,nullMachineType,nullTime,nullTime,false,nullIndex,false,nullIndex)
end

type Job
    index::Integer
	workerIndex::Integer
    tasks::Vector{FactoryTask}

	location::Location
    nearestNodeIndex::Integer
    nearestNodeDist::Float

    releaseTime::Float
    dueTime::Float

    status::JobStatus
    finished::Bool

    # for animation:
	currentLoc::Location
	movedLoc::Bool


    Job() = new(nullIndex,nullIndex,[], Location(),nullIndex,nullDist, nullTime,nullTime, nullJobStatus,false, Location(),false)
    Job(index::Integer,tasks::Vector{FactoryTask},releaseTime::Float,dueTime::Float) = new(index,nullIndex,deepcopy(tasks), startingLoc,nullIndex,nullDist, releaseTime,dueTime, nullJobStatus,false, Location(),false)

end

type Schedule

    index::Integer
    numTasks::Integer

    factoryTaskList::Vector{FactoryTask}

    Schedule() = new(nullIndex,0,Vector{FactoryTask}())
end

type ProductOrder
    index::Integer
    product::ProductType
    size::Integer
    releaseTime::Float
    dueTime::Float

    ProductOrder() = new(nullIndex,nullProductType,nullIndex,nullTime)
    ProductOrder(index::Integer, product::ProductType, size::Integer, arrivalTime::Float, dueTime::Float) = new(index,product,size,arrivalTime,dueTime)
end

type Event
	index::Integer # index of event in list of events that have occurred (not for sim.eventList)
	parentIndex::Integer # index of parent event
	eventType::EventType
	time::Float
	task::FactoryTask
	workerIndex::Integer
	jobIndex::Integer
    machineIndex::Integer


	Event() = new(nullIndex, nullIndex, nullEvent, nullTime, FactoryTask(), nullIndex, nullIndex, nullIndex)
end

type Worker
    index::Integer
    jobIndex::Integer
    status::WorkerStatus

    # for animation:
    currentLoc::Location
    movedLoc::Bool

	location::Location
    route::Route

    currentTask::FactoryTask

    Worker() = new(nullIndex,nullIndex,nullWorkerStatus,Location(),false,Location(),Route(),FactoryTask())

end

type Machine
    index::Integer
    machineType::MachineType
    location::Location
    nearestNodeIndex::Integer
    nearestNodeDist::Float
    isBusy::Bool

    Machine() = new(nullIndex,nullMachineType,Location(),nullIndex,false)
end

type Resimulation
	# parameters:
	use::Bool # true if resimulating (will follow event trace), false otherwise
	timeTolerance::Float

	events::Vector{Event}
	eventsChildren::Vector{Vector{Event}} # eventsChildren[i] gives events that are children of event i
	prevEventIndex::Int # index of previous event in events field

	Resimulation() = new(false, 0.0,
		[], [], nullIndex)
end

type Simulation
	startTime::Float
	time::Float
	endTime::Float # calculated after simulating

	# world:
	net::Network
	travel::Travel
	map::Map
	grid::Grid
    startNodeIndex::Integer
    workerStartingLocation::Location

    productOrders::Vector{ProductOrder}
    productDict::Dict{ProductType,Vector{FactoryTask}}
	jobs::Vector{Job}
	tasks::Vector{FactoryTask}
	workers::Vector{Worker}
	machines::Vector{Machine}
	workerFree::Bool

    # Bugfixing
    numCompletedTasks::Integer
    numCompletedJobs::Integer

	eventList::Vector{Event} # events to occur now or in future
	eventIndex::Integer # index of event in events that have occurred
	queuedTaskList::Vector{FactoryTask} # keep track of queued calls. Calls can be queued after call arrivalTime + dispatchDelay

    resim::Resimulation

	# for animation:
	currentTasks::Set{FactoryTask} # all calls between arrival and service finish at current time
	previousTasks::Set{FactoryTask} # calls in currentCalls for previous frame

	# files/folders:
	inputPath::String
	outputPath::String
	inputFiles::Dict{String,File} # given input file name (e.g. "workers"), returns file information
	outputFiles::Dict{String,File}
	eventsFileIO::IOStream # write simulation trace of events to this file

	writeOutput::Bool # true if outputFiles should be used to write output (false if animating)

	used::Bool # true if simulation has started running (and so restarting would require copying from backup)
	complete::Bool # true if simulation has ended (no events remaining)
	backup::Simulation # copy of simulation, for restarts (does not include net, travel, grid, or resim, as copying these would waste memory)

	configRootElt::XMLElement

	Simulation() = new(nullTime, nullTime, nullTime,
		Network(), Travel(), Map(), Grid(),nullIndex,Location(),
		[],Dict(),[], [], [], [], false,
        0,0,
		[], 0, [],
        Resimulation(),
		Set(), Set(),
		"", "", Dict(), Dict(), IOStream(""),
		false,
		false, false)
end
