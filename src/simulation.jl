function simulateEvent!(sim::Simulation, event::Event)
	# format:
	# next event may change relevant ambulance / call fields at event.time
	# event may then trigger future events / cancel scheduled events

	assert(sim.time == event.time)
	eventType = event.eventType
	if eventType == nullEvent
		error("null event")


	elseif eventType == taskReleased
		# add released task to the queue and check for available workers
		push!(sim.queuedTaskList,event.task)
		push!(sim.currentTasks,event.task)
		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)

		##################################

	elseif eventType == checkAssign
		# if a worker is available assign task to worker
		checkFreeWorker!(sim)
		if sim.workerFree
			addEvent!(sim.eventList; parentEvent = event, eventType = assignAvailableWorker, time = sim.time)
		end
		##################################

	elseif eventType == assignClosestAvailableWorker
		# get next task in queued tasks and assign the closest worker to that task
		assert(length(sim.queuedTaskList)>0)
		possibleQueued = filter(t -> !isEmpty(t.machineType),sim.queuedTaskList)
		if !isEmpty(possibleQueued)
			event.task = popfirst!(possibleQueued)
			# remove task frome queue
			filter!(t -> t ≠ event.task, sim.queuedTaskList)
			event.batchIndex = event.task.batchIndex
			freeWorkers = filter(w -> !w.isBusy,sim.workers)
			worker = findClosestWorker(freeWorkers,sim.batches[event.batchIndex].location)
			assert(event.task.workerIndex==nullIndex)
			event.task.workerIndex = worker.index
			worker.currentTask = event.task
			if sim.workerFree
				addEvent!(sim.eventList; parentEvent = event, eventType = moveToBatch, time = sim.time, workerIndex = worker.index,batchIndex = event.batchIndex,task = event.task)
			end

			if !isEmpty(possibleQueued)
				addEvent!(sim.eventList, eventType = checkAssign, time = sim.time)
			end
		end

		##################################
	elseif eventType == moveToBatch
		# move worker to batch of current task
		worker = findClosestWorker(filter(w -> !w.isBusy,sim.workers),event.task)
		worker.isBusy=true
		location = sim.batches[event.batchIndex].location

		(sim.batches[event.batchIndex].nearestNodeIndex, dist) = findNearestNodeInGrid(sim.map, sim.grid, sim.net.fGraph.nodes, location)
		if dist>0
			changeRoute!(sim, sim.workers[event.workerIndex].route, sim.time, location, sim.batches[event.batchIndex].nearestNodeIndex)
			time = sim.workers[event.workerIndex].route.endTime
		else
			time = sim.time
		end
		addEvent!(sim.eventList; parentEvent = event, eventType = arriveAtBatch, time = time, workerIndex = worker.index,batchIndex = event.batchIndex,task = event.task)
		##################################

	elseif eventType == arriveAtBatch
		# process worker arriving at batch. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		freeMachines = freeMachines(event.task.machineType)
		if length(freeMachines)>0
			addEvent!(sim.eventList; parentEvent = event, eventType = MoveBatchToMachine, time = sim.time, workerIndex = worker.index,batchIndex = event.batchIndex,task = event.task)
		else
			addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = sim.time, workerIndex = worker.index)
			event.task.workerIndex=nullIndex
			event.task.workerArrived = false
			pushfirst!(sim.queuedTaskList,event.task)
		end
		##################################
	elseif eventType == moveBatchToMachine
		# move worker and batch to machine for processing if free machine, else free worker and add task back to queue
		assert(length(freeMachines(event.task.machineType))>0)
		event.task.workerArrived = true
		closestMachine = findClosestMachine(freeMachines,bLocation)
		closestMachine.isBusy = true
		event.task.machineIndex = closestMachine.index
		changeRoute!(sim, sim.workers[event.workerIndex].route, sim.time,closestMachine.location, closestMachine.nearestNodeIndex)
		addEvent!(sim.eventList; parentEvent = event, eventType = startMachineProcess, time =  sim.workers[event.workerIndex].route.endTime, workerIndex = worker.index, batchIndex = event.batchIndex,task = event.task)

		##################################
	elseif eventType == startMachineProcess
		# process worker arriving at batch. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = sim.time+event.task.withWorker, workerIndex = worker.index)
		addEvent!(sim.eventList; parentEvent = event, eventType = finishTask, time = sim.time+event.task.withoutWorker, workerIndex = worker.index, batchIndex = event.batchIndex,task = event.task)

	elseif eventType == releaseWorker
		# reset worker for further use
		worker = sim.workers[event.workerIndex]
		worker.isBusy=false
		worker.currentTask=FactoryTask()
		if length(sim.queuedTaskList)>0
			addEvent!(sim.eventList; parentEvent = event, eventType = assignAvailableWorker, time = sim.time)
		end

		##################################
	elseif eventType == finishTask
		# move worker and batch to machine for processing if free machine, else free worker and add task back to queue
		batch = sim.batches[event.batchIndex]
		task=event.task
		task.isComplete = true
		filter!(t -> t.index≠task.index,batch.toDO)
		push!(batch.completed,task)
		if isEmpty(batch.toDo)
			batch.finished = true
		end
		delete!(sim.currentTasks, task)


		##################################
	else
		# unspecified event
		error()
	end

end

function addEvent!(eventList::Vector{Event};
	parentEvent::Event = Event(), eventType::EventType = nullEvent, time::Float = nullTime, workerIndex::Integer = nullIndex, batchIndex::Integer = nullIndex, task::FactoryTask = FactoryTask())

	event = Event()
	event.parentIndex = parentEvent.index
	event.eventType = eventType
	event.time = time
	event.workerIndex = workerIndex
	event.batchIndex = batchIndex
	event.task = task

	# find where to insert event into list
	# maintain sorting by time, events nearer to end of list are sooner
	i = findlast(e -> e.time >= event.time, eventList) + 1
	insert!(eventList, i, event)


	return event
end

function checkFreeWorker!(sim::Simulation)
	sim.workerFree=false
	for worker in sim.workers
		if !worker.isBusy
			sim.workerFree=true
			return
		end
	end
end

function freeMachines(machineType::MachineType)
	# returns all free machines of matching machine type
	return filter(m -> m.machineType == machineType && !m.isBusy,sim.machines)
end

function findClosestWorker(workers::Vector{Worker},loc::Location)
	return workers[1]
end

function findClosestMachine(machines::Vector{Machine},loc::Location)
	return machines[1]
end





## JEMSS function for no priority allowing use of type FactorySim.Simulation
function changeRoute!(sim::Simulation, route::Route, startTime::Float, endLoc::Location, endFNode::Int)
	changeRoute!(sim, route, lowPriority, startTime, endLoc, endFNode)
end
## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function changeRoute!(sim::Simulation, route::Route, priority::Priority, startTime::Float, endLoc::Location, endFNode::Int)

	# shorthand:
	map = sim.map
	net = sim.net
	travel = sim.travel

	# get data on current route before changing
	startLoc = getRouteCurrentLocation!(net, route, startTime)

	travelMode = getTravelMode!(travel, priority, startTime)

	(startFNode, startFNodeTravelTime) = getRouteNextNode!(sim, route, travelMode.index, startTime)
	startFNodeTime = startTime + startFNodeTravelTime

	(travelTime, rNodes) = shortestPathTravelTime(net, travelMode.index, startFNode, endFNode)

	# shorthand:
	fNetTravel = travelMode.fNetTravel
	fNodeFromRNodeTime = fNetTravel.fNodeFromRNodeTime
	fNodeToRNodeTime = fNetTravel.fNodeToRNodeTime

	## change route

	route.priority = priority
	route.travelModeIndex = travelMode.index

	# start and end fNodes and times
	route.startFNode = startFNode
	route.startFNodeTime = startFNodeTime
	route.endFNode = endFNode
	route.endFNodeTime = startFNodeTime + travelTime

	# start and end rNodes and times
	route.startRNode = rNodes[1]
	route.endRNode = rNodes[2]
	if route.startRNode != nullIndex
		assert(route.endRNode != nullIndex)
		route.startRNodeTime = startFNodeTime + fNodeToRNodeTime[startFNode][route.startRNode]
		route.endRNodeTime = route.endFNodeTime - fNodeFromRNodeTime[endFNode][route.endRNode]
	else
		route.startRNodeTime = nullTime
		route.endRNodeTime = nullTime
	end

	# start and end locations and times
	route.startLoc = startLoc
	route.startTime = startTime
	route.endLoc = endLoc
	route.endTime = route.endFNodeTime + offRoadTravelTime(travelMode, map, net.fGraph.nodes[endFNode].location, endLoc)

	# recent rArc, recent fNode, next fNode
	setRouteStateBeforeStartFNode!(route, startTime)

	# first rArc
	setRouteFirstRArc!(net, route)
end

## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function getRouteNextNode!(sim::Simulation, route::Route, travelModeIndex::Int, time::Float)

	# shorthand:
	map = sim.map
	net = sim.net
	travelModes = sim.travel.modes

	# first need to update route
	updateRouteToTime!(net, route, time)

	# if route already finished, return nearest node
	# also return travel time to node based on route.endLoc
	if route.endTime <= time
		nearestFNode = route.endFNode
		travelTime = offRoadTravelTime(travelModes[travelModeIndex], map, route.endLoc, net.fGraph.nodes[nearestFNode].location)

		return nearestFNode, travelTime
	end

	nextFNode = nullIndex # init
	travelTime = nullTime # init
	if route.nextFNode != nullIndex
		# between startLoc and endFNode, go to nextFNode
		nextFNode = route.nextFNode
		travelTime = route.nextFNodeTime - time
	else
		# between endFNode and endLoc, return to recentFNode
		nextFNode = route.recentFNode
		travelTime = time - route.recentFNodeTime
	end

	# testing: changing travel time to match bartsim code...
	# scale travel time according to any change in travel mode
	if route.travelModeIndex != travelModeIndex
		if route.nextFNode == nullIndex
			# currently somewhere between route.endFNode and route.endLoc
			travelTime *= travelModes[route.travelModeIndex].offRoadSpeed / travelModes[travelModeIndex].offRoadSpeed
		end
	end

	if checkMode
		assert(nextFNode != nullIndex)
		assert(travelTime >= 0)
	end

	return nextFNode, travelTime
end
## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function simulateToTime!(sim::Simulation, time::Float)
	while !sim.complete && sim.eventList[end].time <= time # eventList must remain sorted by non-increasing time
		simulateNextEvent!(sim)
	end
end
## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function simulateToEnd!(sim::Simulation)
	simulateToTime!(sim, Inf)
end
## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function simulate!(sim::Simulation; timeStep::Float = 1.0)
	println("running simulation...")
	startTime = time()
	nextTime = startTime + timeStep
	printProgress() = print(@sprintf("\rsim duration: %-9.2f real duration: %.2f seconds", sim.time - sim.startTime, time()-startTime))
	while !sim.complete
		simulateNextEvent!(sim)
		if time() > nextTime
			printProgress()
			nextTime += timeStep
		end
	end
	printProgress()
	println("\n...simulation complete")
end
## slightly changed function from JEMSS, needed here to allow use of type FactorySim.Simulation
function simulateNextEvent!(sim::Simulation)
	# get next event, update event index and sim time
	event = getNextEvent!(sim.eventList)
	if event.eventType == nullEvent
		error()
	end
	sim.used = true
	sim.eventIndex += 1
	event.index = sim.eventIndex
	sim.time = event.time

	if sim.writeOutput
		writeEventToFile!(sim, event)
	end

	simulateEvent!(sim, event)

	if length(sim.eventList) == 0
		# simulation complete
		assert(sim.endTime == nullTime)
		assert(sim.complete == false)
		sim.endTime = sim.time
		sim.complete = true
	end
end
