

function addEvent!(eventList::Vector{Event};
	parentEvent::Event = Event(), eventType::EventType = nullEvent, time::Float = nullTime,
	workerIndex::Integer = nullIndex, jobIndex::Integer = nullIndex, machineIndex::Integer = nullIndex,
	task::FactoryTask = FactoryTask())

	event = Event()
	event.parentIndex = parentEvent.index
	event.eventType = eventType
	event.time = time
	event.workerIndex = workerIndex
	event.jobIndex = jobIndex
	event.machineIndex = machineIndex
	event.task = task

	# find where to insert event into list
	# maintain sorting by time, events nearer to end of list are sooner
	i = findlast(e -> e.time >= event.time, eventList) + 1
	insert!(eventList, i, event)


	return event
end


function addEvent!(eventList::Vector{Event}, task::FactoryTask, startTime::Float)
	addEvent!(eventList, eventType=taskReleased,time=startTime,jobIndex = task.jobIndex,task=task)
end

function checkFreeWorker!(sim::Simulation)
	sim.workerFree=false
	for worker in sim.workers
		if worker.status==workerIdle
			sim.workerFree=true
			return
		end
	end
end

function freeMachines(sim::Simulation,machineType::MachineType)
	# returns all free machines of matching machine type
	return filter(m -> (m.machineType == machineType && !m.isBusy),sim.machines)
end

function isFreeMachine(sim::Simulation,machineType::MachineType)
	return !isempty(filter(m -> (m.machineType == machineType && !m.isBusy),sim.machines))
end

## Based off findNearestFreeAmbToCall function in JEMSS
function findClosestWorker(sim::Simulation,currentJob::Job)
	# Find the nearest node to the job location> This is independent of the workers
	(node2,dist2) = (currentJob.nearestNodeIndex,currentJob.nearestNodeDist) # is nearestNodeIndex set?
	travelMode = sim.travel.modes[1] # Could change for when the worker is moving a job
	time2 = offRoadTravelTime(travelMode, dist2) # traveltime between job and nearest node

	# Of all the free workers, find the closest worker
	workerIndex = nullIndex
	minTime = Inf
	# Select only free workers
	freeWorkers = filter(w -> w.status==workerIdle,sim.workers) # select only the free workers
	for worker in freeWorkers
		# next/nearest node in worker route
		(node1, time1) = getRouteNextNode!(sim,worker.route,1, sim.time) #set travelModeIndex to 1.
		(travelTime, rNodes) = shortestPathTravelTime(sim.net,1, node1, node2) # time spent on network
		travelTime += time1 + time2
		if minTime>travelTime
			workerIndex = worker.index
			minTime = travelTime
		end
	end
	return sim.workers[workerIndex]
end

## based off nearestHospitalToCall function in JEMSS
function nearestMachineToJob(sim::Simulation, job::Job, machineType::MachineType)
	# Find the nearest node to the job location> This is independent of the workers
	(node1,dist1) = (job.nearestNodeIndex,job.nearestNodeDist) # is nearestNodeIndex set?
	travelMode = sim.travel.modes[1] # Could change for when the worker is moving a job
	time1 = offRoadTravelTime(travelMode, dist1) # traveltime between job and nearest node

	# Of all the free workers, find the closest worker
	machineIndex = nullIndex
	minTime = Inf
	# Select only free workers
	freeMachines = FactorySim.freeMachines(sim,machineType) # select only the free workers
	for machine in freeMachines
		# next/nearest node in worker route
		(node2, dist2) = (machine.nearestNodeIndex,machine.nearestNodeDist)
		time2 = offRoadTravelTime(travelMode, dist2)
		(travelTime, rNodes) = shortestPathTravelTime(sim.net,1, node1, node2) # time spent on network
		travelTime += time1 + time2
		if minTime>travelTime
			machineIndex = machine.index
			minTime = travelTime
		end
	end
	return sim.machines[machineIndex]
end

function simulateFactoryEvent!(sim::Simulation, event::Event)
	# format:
	# next event may change relevant ambulance / call fields at event.time
	# event may then trigger future events / cancel scheduled events

	assert(sim.time == event.time)
	eventType = event.eventType
	if eventType == nullEvent
		error("null event")


	elseif eventType == taskReleased
		# add released task to the queue and check for available workers
		sim.jobs[event.task.jobIndex].status = jobQueued
		push!(sim.queuedTaskList,event.task)
		push!(sim.currentTasks,event.task)
		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)

		##################################

	elseif eventType == checkAssign
		# if a worker is available assign task to worker
		checkFreeWorker!(sim)
		if sim.workerFree
			addEvent!(sim.eventList; parentEvent = event, eventType = assignClosestAvailableWorker, time = sim.time)
		end
		##################################

	elseif eventType == assignClosestAvailableWorker
		# get next task in queued tasks and assign the closest worker to that task
		possibleQueued = filter(t -> FactorySim.isFreeMachine(sim,t.machineType),sim.queuedTaskList)
		if !isempty(possibleQueued)
			event.task = shift!(possibleQueued)
			# remove task frome queue
			filter!(t -> t ≠ event.task, sim.queuedTaskList)
			event.jobIndex = event.task.jobIndex #Set the current job

			# find the closest free worker to pair with task
			job = sim.jobs[event.jobIndex]
			(job.nearestNodeIndex, dist) = findNearestNodeInGrid(sim.map, sim.grid, sim.net.fGraph.nodes, job.location)
			worker = findClosestWorker(sim,job)

			# assigns worker to task
			assert(event.task.workerIndex==nullIndex)
			event.task.workerIndex = worker.index
			worker.currentTask = event.task
			# move worker to job location
			job.status = jobWaitingForWorker
			job.workerIndex = worker.index
			worker.status = workerMovingToJob
			addEvent!(sim.eventList; parentEvent = event, eventType = moveToJob, time = sim.time, workerIndex = worker.index,jobIndex = event.jobIndex,task = event.task)

			# if more tasks available check for more free workers
			if !isempty(possibleQueued)
				addEvent!(sim.eventList, eventType = checkAssign, time = sim.time)
			end
		end

		##################################

	elseif eventType == moveToJob
		## move worker to job of current task
		# find location of job
		location = sim.jobs[event.jobIndex].location

		# set worker as busy
		worker = sim.workers[event.workerIndex]
		worker.jobIndex = event.jobIndex

		#find distance and nearest node of job from worker
		(sim.jobs[event.jobIndex].nearestNodeIndex, dist) = findNearestNodeInGrid(sim.map, sim.grid, sim.net.fGraph.nodes, location)
		if dist>0
			changeRoute!(sim, sim.workers[event.workerIndex].route, sim.time, location, sim.jobs[event.jobIndex].nearestNodeIndex)
			arrivalTime = sim.workers[event.workerIndex].route.endTime
		else
			arrivalTime = sim.time
		end
		addEvent!(sim.eventList; parentEvent = event, eventType = arriveAtJob, time = arrivalTime, workerIndex = worker.index,jobIndex = event.jobIndex,task = event.task)
		##################################

	elseif eventType == arriveAtJob
		# process worker arriving at job. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		freeMachines = FactorySim.freeMachines(sim,event.task.machineType)
		sim.workers[event.workerIndex].status = workerAtJob
		if length(freeMachines)>0
			addEvent!(sim.eventList; parentEvent = event, eventType = moveJobToMachine, time = sim.time, workerIndex = event.workerIndex,jobIndex = event.jobIndex,task = event.task)
		else
			addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = sim.time, workerIndex = event.workerIndex)
			event.task.workerIndex=nullIndex
			event.task.workerArrived = false
			sim.jobs[event.jobIndex].status = jobQueued
			unshift!(sim.queuedTaskList,event.task)
		end
		##################################

	elseif eventType == moveJobToMachine
		# move worker and job to machine for processing if free machine, else free worker and add task back to queue
		machineType = event.task.machineType
		assert(length(FactorySim.freeMachines(sim,machineType))>0)

		# set task to have workerArrived
		assert(event.task.workerArrived == false)
		event.task.workerArrived = true


		# find closest machine and attach to task
		job = sim.jobs[event.jobIndex]
		job.status = jobGoingToMachine
		worker = sim.workers[event.workerIndex]
		worker.status = workerMovingToMachine
		closestMachine = nearestMachineToJob(sim,job,machineType)
		closestMachine.isBusy = true
		event.task.machineIndex = closestMachine.index
		event.machineIndex = closestMachine.index

		#move worker and job to machine
		changeRoute!(sim, worker.route, sim.time,closestMachine.location, closestMachine.nearestNodeIndex)
		addEvent!(sim.eventList; parentEvent = event, eventType = startMachineProcess, time =  worker.route.endTime,
		workerIndex = event.workerIndex, jobIndex = event.jobIndex,machineIndex = event.machineIndex, task = event.task)

		##################################

	elseif eventType == startMachineProcess
		# process worker arriving at job. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		sim.jobs[event.task.jobIndex].location = sim.machines[event.machineIndex].location
		# update worker and job status
		sim.workers[event.workerIndex].status = workerProcessingJob
		sim.jobs[event.jobIndex].status = jobAtMachine
		# release worker when no longer needed. Finish task when process is finished
		addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = (sim.time+event.task.withWorker), workerIndex = event.workerIndex)
		addEvent!(sim.eventList; parentEvent = event, eventType = finishTask, time = (sim.time+event.task.withoutWorker), workerIndex = event.workerIndex, jobIndex = event.jobIndex,machineIndex=event.machineIndex, task = event.task)

	elseif eventType == releaseWorker
		# reset worker for further use
		worker = sim.workers[event.workerIndex]
		worker.status = workerIdle
		worker.jobIndex = nullIndex
		worker.currentTask=FactoryTask()

		# attempts to reassign worker
		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)

		##################################

	elseif eventType == finishTask
		# move worker and job to machine for processing if free machine, else free worker and add task back to queue
		job = sim.jobs[event.jobIndex]
		job.workerIndex=nullIndex
		job.status = jobProcessed
		task=event.task
		machine = sim.machines[event.machineIndex]
		task.isComplete = true
		machine.isBusy = false

		sim.numCompletedTasks+=1
		# if no more tasks, complete job, else add next task to queue

		if isempty(filter(t->!t.isComplete,job.tasks))
			job.finished = true
			sim.numCompletedJobs+=1
		else
			addEvent!(sim.eventList, job.tasks[task.withinJobIndex+1], event.time)
		end

		# remove task for animation
		delete!(sim.currentTasks, task)

		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)
		##################################
	else
		# unspecified event
		error()
	end

end

function initWorker!(sim::Simulation, worker::Worker)
	assert(worker.index != nullIndex)

	# create route that mimics ambulance driving from nowhere,
	# to a node (nearest to station), then to station, before simulation began
	worker.route = Route()
	worker.route.startLoc = Location()
	worker.route.endLoc = sim.workerStartingLocation
	worker.route.endTime = sim.startTime
	worker.route.endFNode = sim.startNodeIndex
	worker.status = workerIdle
end




function initSimulation(configFilename::String;
	createBackup::Bool = true, allowWriteOutput::Bool = false)

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
	sim.startTime=0;
	sim.time = sim.startTime


	sim.workers = readWorkersFile(simFilePath("workers"))
	sim.productOrders = readProductOrdersFile(simFilePath("productOrders"))
	sim.machines = readMachinesFile(simFilePath("machines"))
	sim.productDict = readProductDictFile(simFilePath("productDict"))
	sim.jobs = decomposeOrder(sim.productOrders,sim.productDict)


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
	JEMSS.initGraph!(fGraph)
	initTime(t)

	initMessage(t, "checking fGraph")
	JEMSS.checkGraph(fGraph, map)
	initTime(t)

	initMessage(t, "initialising fNetTravels")
	JEMSS.initFNetTravels!(net, arcTravelTimes)
	initTime(t)

	initMessage(t, "creating rGraph from fGraph")
	JEMSS.createRGraphFromFGraph!(net)
	initTime(t)
	println("fNodes: ", length(net.fGraph.nodes), ", rNodes: ", length(net.rGraph.nodes))

	initMessage(t, "checking rGraph")
	JEMSS.checkGraph(net.rGraph, map)
	initTime(t)

	if rNetTravelsLoaded != []
		println("using data from rNetTravels file")
		try
			initMessage(t, "creating rNetTravels from fNetTravels")
			JEMSS.createRNetTravelsFromFNetTravels!(net; rNetTravelsLoaded = rNetTravelsLoaded)
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
		JEMSS.createRNetTravelsFromFNetTravels!(net)
		initTime(t)
		if rNetTravelsFilename != ""
			initMessage(t, "saving rNetTravels to file")
			JEMSS.writeRNetTravelsFile(rNetTravelsFilename, net.rNetTravels)
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
	JEMSS.gridPlaceNodes!(map, grid, fGraph.nodes)
	initTime(t)

	println("nodes: ", length(fGraph.nodes), ", grid size: ", nx, " x ", ny)

	##################
	# sim - ambulances, calls, hospitals, stations...

	initMessage(t, "adding workers, calls, etc")

	# for each call, hospital, and station, find neareset node
	for m in sim.machines
		(m.nearestNodeIndex, m.nearestNodeDist) = findNearestNodeInGrid(map, grid, fGraph.nodes, m.location)
	end

	commonFNodes = sort(unique([m.nearestNodeIndex for m in sim.machines]))
	JEMSS.setCommonFNodes!(net, commonFNodes)
	# create event list
	# try to add events to eventList in reverse time order, to reduce sorting required
	sim.eventList = Vector{Event}(0)

	# add first task in each job to event list
	for j in sim.jobs
		addEvent!(sim.eventList, j.tasks[1], sim.startTime)
	end

	sim.workerStartingLocation = startingLoc
	(sim.startNodeIndex, _) = findNearestNodeInGrid(map, grid, fGraph.nodes, sim.workerStartingLocation)


	# initialise worker routes
	for w in sim.workers
		initWorker!(sim,w)
	end

	initTime(t)

	if createBackup
		initMessage(t, "creating sim backup")
		backupSim!(sim) # for restarting sim
		initTime(t)
	end

	return sim
end


function backupSim!(sim::Simulation)
	assert(!sim.used)

	# remove net, travel, grid, and resim from sim before copying sim
	(net, travel, grid) = (sim.net, sim.travel, sim.grid)
	(sim.net, sim.travel, sim.grid) = (Network(), Travel(), Grid())

	sim.backup = deepcopy(sim)

	(sim.net, sim.travel, sim.grid) = (net, travel, grid)
end

# reset sim from sim.backup
function resetSim!(sim::Simulation)
	assert(!sim.backup.used)

	if sim.used
		fnames = Set(fieldnames(sim))
		fnamesDontCopy = Set([:backup, :net, :travel, :grid]) # will not (yet) copy these fields from sim.backup to sim
		# note that sim.backup does not contain net, travel, grid, or resim
		setdiff!(fnames, fnamesDontCopy) # remove fnamesDontCopy from fnames
		for fname in fnames
			try
				setfield!(sim, fname, deepcopy(getfield(sim.backup, fname)))
			end
		end

		sim.jobs = decomposeOrder(sim.productOrders,sim.productDict)
		# reset travel state
		sim.travel.recentSetsStartTimesIndex = 1
	end
end
