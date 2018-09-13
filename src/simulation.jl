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
			event.jobIndex = event.task.jobIndex
			freeWorkers = filter(w -> !w.isBusy,sim.workers)
			worker = findClosestWorker(freeWorkers,sim.jobs[event.jobIndex].location)
			assert(event.task.workerIndex==nullIndex)
			event.task.workerIndex = worker.index
			worker.currentTask = event.task
			if sim.workerFree
				addEvent!(sim.eventList; parentEvent = event, eventType = moveToJob, time = sim.time, workerIndex = worker.index,jobIndex = event.jobIndex,task = event.task)
			end

			if !isEmpty(possibleQueued)
				addEvent!(sim.eventList, eventType = checkAssign, time = sim.time)
			end
		end

		##################################
	elseif eventType == moveToJob
		# move worker to job of current task
		worker = findClosestWorker(filter(w -> !w.isBusy,sim.workers),event.task)
		worker.isBusy=true
		location = sim.jobs[event.jobIndex].location

		(sim.jobs[event.jobIndex].nearestNodeIndex, dist) = findNearestNodeInGrid(sim.map, sim.grid, sim.net.fGraph.nodes, location)
		if dist>0
			changeRoute!(sim, sim.workers[event.workerIndex].route, sim.time, location, sim.jobs[event.jobIndex].nearestNodeIndex)
			time = sim.workers[event.workerIndex].route.endTime
		else
			time = sim.time
		end
		addEvent!(sim.eventList; parentEvent = event, eventType = arriveAtJob, time = time, workerIndex = worker.index,jobIndex = event.jobIndex,task = event.task)
		##################################

	elseif eventType == arriveAtJob
		# process worker arriving at job. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		freeMachines = freeMachines(event.task.machineType)
		if length(freeMachines)>0
			addEvent!(sim.eventList; parentEvent = event, eventType = MoveJobToMachine, time = sim.time, workerIndex = worker.index,jobIndex = event.jobIndex,task = event.task)
		else
			addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = sim.time, workerIndex = worker.index)
			event.task.workerIndex=nullIndex
			event.task.workerArrived = false
			pushfirst!(sim.queuedTaskList,event.task)
		end
		##################################
	elseif eventType == moveJobToMachine
		# move worker and job to machine for processing if free machine, else free worker and add task back to queue
		assert(length(freeMachines(event.task.machineType))>0)
		event.task.workerArrived = true
		closestMachine = findClosestMachine(freeMachines,bLocation)
		closestMachine.isBusy = true
		event.task.machineIndex = closestMachine.index
		changeRoute!(sim, sim.workers[event.workerIndex].route, sim.time,closestMachine.location, closestMachine.nearestNodeIndex)
		addEvent!(sim.eventList; parentEvent = event, eventType = startMachineProcess, time =  sim.workers[event.workerIndex].route.endTime, workerIndex = worker.index, jobIndex = event.jobIndex,task = event.task)

		##################################
	elseif eventType == startMachineProcess
		# process worker arriving at job. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = sim.time+event.task.withWorker, workerIndex = worker.index)
		addEvent!(sim.eventList; parentEvent = event, eventType = finishTask, time = sim.time+event.task.withoutWorker, workerIndex = worker.index, jobIndex = event.jobIndex,task = event.task)

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
		# move worker and job to machine for processing if free machine, else free worker and add task back to queue
		job = sim.jobs[event.jobIndex]
		task=event.task
		task.isComplete = true
		filter!(t -> t.index≠task.index,job.toDO)
		push!(job.completed,task)
		if isEmpty(job.toDo)
			job.finished = true
		end
		delete!(sim.currentTasks, task)


		##################################
	else
		# unspecified event
		error()
	end

end

function addEvent!(eventList::Vector{Event};
	parentEvent::Event = Event(), eventType::EventType = nullEvent, time::Float = nullTime, workerIndex::Integer = nullIndex, jobIndex::Integer = nullIndex, task::FactoryTask = FactoryTask())

	event = Event()
	event.parentIndex = parentEvent.index
	event.eventType = eventType
	event.time = time
	event.workerIndex = workerIndex
	event.jobIndex = jobIndex
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






function initSimulation(configFilename::String;
	allowWriteOutput::Bool = false)

	# read sim config xml file
	rootElt = xmlFileRoot(configFilename)
	@assert(name(rootElt) == "simConfig", string("xml root has incorrect name: ", name(rootElt)))

	# for progress messages:
	t = Vector{Float}(1)
	initMessage(t, msg) = (t[1] = time(); print(msg))
	initTime(t) = println(": ", round(time() - t[1], 2), " seconds")

	##################
	# sim config

	initMessage(t, "reading config file data")

	sim = Simulation()
	sim.configRootElt = rootElt

	# input
	sim.inputPath = abspath(eltContentInterpVal(rootElt, "inputPath"))
	simFilesElt = findElt(rootElt, "simFiles")
	inputFiles = childrenNodeNames(simFilesElt)
	sim.inputFiles = Dict{String,File}()
	for inputFile in inputFiles
		file = File()
		file.name = eltContent(simFilesElt, inputFile)
		file.path = joinpath(sim.inputPath, file.name)
		if inputFile != "rNetTravels" # do not need checksum of rNetTravels file
			file.checksum = fileChecksum(file.path)
		end
		sim.inputFiles[inputFile] = file
	end

	# output
	sim.writeOutput = allowWriteOutput && eltContentVal(rootElt, "writeOutput")
	sim.outputPath = abspath(eltContentInterpVal(rootElt, "outputPath"))
	outputFilesElt = findElt(rootElt, "outputFiles")
	outputFiles = childrenNodeNames(outputFilesElt)
	sim.outputFiles = Dict{String,File}()
	for outputFile in outputFiles
		file = File()
		file.name = eltContent(outputFilesElt, outputFile)
		file.path = joinpath(sim.outputPath, file.name)
		sim.outputFiles[outputFile] = file
	end

	initTime(t)

	##################
	# read simulation input files

	initMessage(t, "reading input data")

	simFilePath(name::String) = sim.inputFiles[name].path

	# read sim data
	sim.workers = readWorkersFile(simFilePath("workers"))
	sim.startTime=0;
	sim.time = sim.startTime
	sim.productOrders = readProductOrdersFile(simFilePath("productOrders"))
	sim.machines = readMachinesFile(simFilePath("machines"))
	sim.jobs = decomposeOrder()

	# read network data
	sim.net = Network()
	net = sim.net # shorthand
	fGraph = net.fGraph # shorthand
	fGraph.nodes = readNodesFile(simFilePath("nodes"))
	(fGraph.arcs, arcTravelTimes) = readArcsFile(simFilePath("arcs"))

	# read rNetTravels from file, if saved
	rNetTravelsLoaded = NetTravel[]
	rNetTravelsFilename = ""
	if haskey(sim.inputFiles, "rNetTravels")
		rNetTravelsFilename = simFilePath("rNetTravels")
		if isfile(rNetTravelsFilename)
			rNetTravelsLoaded = readRNetTravelsFile(rNetTravelsFilename)
		elseif !isdir(dirname(rNetTravelsFilename)) || splitdir(rNetTravelsFilename)[2] == ""
			# rNetTravelsFilename is invalid
			rNetTravelsFilename = ""
		else
			# save net.rNetTravels to file once calculated
		end
	end

	# read misc
	sim.map = readMapFile(simFilePath("map"))
	map = sim.map # shorthand
	sim.travel = readTravelFile(simFilePath("travel"))

	initTime(t)

	##################
	# network

	initMessage(t, "initialising fGraph")
	initGraph!(fGraph)
	initTime(t)

	initMessage(t, "checking fGraph")
	checkGraph(fGraph, map)
	initTime(t)

	initMessage(t, "initialising fNetTravels")
	initFNetTravels!(net, arcTravelTimes)
	initTime(t)

	initMessage(t, "creating rGraph from fGraph")
	createRGraphFromFGraph!(net)
	initTime(t)
	println("fNodes: ", length(net.fGraph.nodes), ", rNodes: ", length(net.rGraph.nodes))

	initMessage(t, "checking rGraph")
	checkGraph(net.rGraph, map)
	initTime(t)

	if rNetTravelsLoaded != []
		println("using data from rNetTravels file")
		try
			initMessage(t, "creating rNetTravels from fNetTravels")
			createRNetTravelsFromFNetTravels!(net; rNetTravelsLoaded = rNetTravelsLoaded)
			initTime(t)
		catch
			println()
			warn("failed to use data from rNetTravels file")
			rNetTravelsLoaded = []
			rNetTravelsFilename = ""
		end
	end
	if rNetTravelsLoaded == []
		initMessage(t, "creating rNetTravels from fNetTravels, and shortest paths")
		createRNetTravelsFromFNetTravels!(net)
		initTime(t)
		if rNetTravelsFilename != ""
			initMessage(t, "saving rNetTravels to file")
			writeRNetTravelsFile(rNetTravelsFilename, net.rNetTravels)
			initTime(t)
		end
	end

	##################
	# travel

	initMessage(t, "initialising travel")

	travel = sim.travel # shorthand
	assert(travel.setsStartTimes[1] <= sim.startTime)
	assert(length(net.fNetTravels) == travel.numModes)
	for travelMode in travel.modes
		travelMode.fNetTravel = net.fNetTravels[travelMode.index]
		travelMode.rNetTravel = net.rNetTravels[travelMode.index]
	end

	initTime(t)

	##################
	# grid

	initMessage(t, "placing nodes in grid")

	# hard-coded grid size
	# grid rects will be roughly square, with one node per square on average
	n = length(fGraph.nodes)
	xDist = map.xRange * map.xScale
	yDist = map.yRange * map.yScale
	nx = Int(ceil(sqrt(n * xDist / yDist)))
	ny = Int(ceil(sqrt(n * yDist / xDist)))

	sim.grid = Grid(map, nx, ny)
	grid = sim.grid # shorthand
	gridPlaceNodes!(map, grid, fGraph.nodes)
	initTime(t)

	println("nodes: ", length(fGraph.nodes), ", grid size: ", nx, " x ", ny)

	##################
	# sim - ambulances, calls, hospitals, stations...

	initMessage(t, "adding ambulances, calls, etc")

	# for each call, hospital, and station, find neareset node
	for c in sim.machines
		(c.nearestNodeIndex, c.nearestNodeDist) = findNearestNodeInGrid(map, grid, fGraph.nodes, c.location)
	end


	# create event list
	# try to add events to eventList in reverse time order, to reduce sorting required
	sim.eventList = Vector{Event}(0)

	# add first call to event list
	addEvent!(sim.eventList, sim.calls[1])

	# create ambulance wake up events
	for a in sim.ambulances
		initAmbulance!(sim, a)
		# currently, this sets ambulances to wake up at start of sim, since wake up and sleep events are not in ambulances file yet
	end

	initTime(t)

	initMessage(t, "storing times between fNodes and common locations")

	# for each station, find time to each node in fGraph for each travel mode, and vice versa (node to station)
	# for each node in fGraph and each travel mode, find nearest hospital
	# requires deterministic and static travel times

	commonFNodes = sort(unique(vcat([h.nearestNodeIndex for h in sim.hospitals], [s.nearestNodeIndex for s in sim.stations])))
	setCommonFNodes!(net, commonFNodes)

	# find the nearest hospital to travel to from each node in fGraph
	numFNodes = length(fGraph.nodes) # shorthand
	for fNetTravel in net.fNetTravels
		fNetTravel.fNodeNearestHospitalIndex = Vector{Int}(numFNodes)
		travelModeIndex = fNetTravel.modeIndex # shorthand
		travelMode = travel.modes[travelModeIndex] # shorthand
		for node in fGraph.nodes
			# find nearest hospital to node
			minTime = Inf
			nearestHospitalIndex = nullIndex
			for hospital in sim.hospitals
				(travelTime, rNodes) = shortestPathTravelTime(net, travelModeIndex, node.index, hospital.nearestNodeIndex)
				travelTime += offRoadTravelTime(travelMode, hospital.nearestNodeDist)
				if travelTime < minTime
					minTime = travelTime
					nearestHospitalIndex = hospital.index
				end
			end
			fNetTravel.fNodeNearestHospitalIndex[node.index] = nearestHospitalIndex
		end
	end

	initTime(t)

	##################
	# decision logic

	decisionElt = findElt(rootElt, "decision")
	sim.addCallToQueue! = eltContentVal(decisionElt, "callQueueing")
	sim.findAmbToDispatch! = eltContentVal(decisionElt, "dispatch")

	# move up
	mud = sim.moveUpData # shorthand
	moveUpElt = findElt(decisionElt, "moveUp")
	moveUpModuleName = eltContent(moveUpElt, "module")





	return sim
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
