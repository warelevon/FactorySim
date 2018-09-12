type FactoryTask

    index::Integer
    batchIndex::Integer
    machineType::MachineType

    withWorker::Float
    withoutWorker::Float
    isComplete::Bool
    workerIndex::Integer
    workerArrived::Bool

    FactoryTask() = new(nullIndex,nullIndex,nullMachineType,nullTime,nullTime,false,nullIndex,false)
end

type Batch
    index::Integer
    size::Integer

	location::Location
    nearestNodeIndex::Integer
	workerInd::Integer


    toDo::Vector{FactoryTask}
    completed::Vector{FactoryTask}
    finished::Bool
    dueTime::Float

    Batch() = new(nullIndex,nullIndex,Location(),nullIndex,nullIndex,[],[],false,nullTime)
    Batch(index::Integer,toDo::Vector{FactoryTask},dueTime::Float) = new(index,nullIndex,startLoc,nullIndex,nullIndex,deepcopy(toDo),[],false,dueTime)

end

type Schedule

    index::Integer
    numTasks::Integer

    factoryTaskList::Vector{FactoryTask}

    Schedule() = new(nullIndex,0,Vector{FactoryTask}())
end

type ProductOrder
    product::ProductType
    size::Integer
    dueTime::Float

    ProductOrder() = new(nullProductType,nullIndex,nullTime)
    ProductOrder(product::ProductType, size::Integer, dueTime::Float) = new(product,size,dueTime)
end

type Event
	index::Int # index of event in list of events that have occurred (not for sim.eventList)
	parentIndex::Int # index of parent event
	eventType::EventType
	time::Float
	task::FactoryTask
	workerIndex::Int
	batchIndex::Int


	Event() = new(nullIndex, nullIndex, nullEvent, nullTime, FactoryTask(), nullIndex, nullIndex)
end

type Worker
    index::Integer
    isBusy::Bool

	location::Location
    route::Route

    currentTask::FactoryTask

    Worker() = new(nullIndex,false,Location(),Route(),FactoryTask())

end

type Machine
    machineType::MachineType
    loc::Location
    nearestNodeIndex::Integer
    isBusy::Bool

    Machine() = new(nullMachineType,Location(),nullIndex,false)
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

	batches::Vector{Batch}
	tasks::Vector{FactoryTask}
	workers::Vector{Worker}
	machines::Vector{Machine}
	workerFree::Bool

	eventList::Vector{Event} # events to occur now or in future
	eventIndex::Int # index of event in events that have occurred
	queuedTaskList::Vector{FactoryTask} # keep track of queued calls. Calls can be queued after call arrivalTime + dispatchDelay


	# for animation:
	currentTasks::Set{FactoryTask} # all calls between arrival and service finish at current time
	previousTasks::Set{FactoryTask} # calls in currentCalls for previous frame

	# files/folders:
	inputPath::String
	outputPath::String
	inputFiles::Dict{String,File} # given input file name (e.g. "ambulances"), returns file information
	outputFiles::Dict{String,File}
	eventsFileIO::IOStream # write simulation trace of events to this file

	writeOutput::Bool # true if outputFiles should be used to write output (false if animating)

	used::Bool # true if simulation has started running (and so restarting would require copying from backup)
	complete::Bool # true if simulation has ended (no events remaining)
	backup::Simulation # copy of simulation, for restarts (does not include net, travel, grid, or resim, as copying these would waste memory)

	configRootElt::XMLElement

	Simulation() = new(nullTime, nullTime, nullTime,
		Network(), Travel(), Map(), Grid(),
		[], [], [], [], false,
		[], 0, [],
		Set(), Set(),
		"", "", Dict(), Dict(), IOStream(""),
		false,
		false, false)
end
