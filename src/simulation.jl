

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
	return filter(m -> (m.machineType == machineType && !m.isBusy && !m.processingBatch),sim.machines)
end

function isFreeMachine(sim::Simulation,machineType::MachineType)
	return !isempty(filter(m -> (m.machineType == machineType && !m.isBusy && !m.processingBatch),sim.machines))
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

function batchCheckStart(sim::Simulation, machine::Machine)
	start = false
	batchSize = length(machine.batchedJobIndeces)
	assert(batchSize <= sim.maxBatchSizeDict[machine.machineType])
	if batchSize == sim.maxBatchSizeDict[machine.machineType]
		start = true
	else
		numSameTypeRemaining = 0
		remainingIndeces = setdiff(Set(1:length(sim.jobs)),machine.batchedJobIndeces)
		for i in remainingIndeces
			numSameTypeRemaining += length(filter(t -> (!t.isComplete && t.machineType==machine.machineType),sim.jobs[i].tasks))
		end
		if numSameTypeRemaining == 0; start = true; end
	end
	return start
end

function batchProcessTime(sim::Simulation,machineType::MachineType,batchedJobIndeces::Vector{Integer})
	processTime = sim.setupTimesDict[machineType]
	for i in batchedJobIndeces
		job = sim.jobs[i]
		processTime += filter(t->t.machineType==machineType,job.tasks)[1].withoutWorker
	end
	return processTime
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
		job = sim.jobs[event.task.jobIndex]
		job.status = jobQueued
		push!(sim.queuedTaskList,event.task)
		push!(sim.currentJobs,job)
		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)

		##################################

	elseif eventType == checkAssign
		# if a worker is available assign task to worker
		checkFreeWorker!(sim)
		if (sim.time>17792.2&&!sim.tested)
			for i = 1:length(sim.machines)
				#Main.Juno.render(sim.machines[i].inputLocation)
			end
			sim.tested = true
		end
		if sim.workerFree
			addEvent!(sim.eventList; parentEvent = event, eventType = assignClosestAvailableWorker, time = sim.time)
		end
		##################################

	elseif eventType == assignClosestAvailableWorker
		# get next task in queued tasks and assign the closest worker to that task
		possibleQueued = sort(filter(t -> FactorySim.isFreeMachine(sim,t.machineType),sim.queuedTaskList),by=t->sim.jobs[t.jobIndex].dueTime)
		if !isempty(possibleQueued)
			event.task = shift!(possibleQueued)
			task = event.task
			# remove task frome queue
			filter!(t -> t ≠ task, sim.queuedTaskList)
			event.jobIndex = task.jobIndex #Set the current job

			# find the closest free worker to pair with task
			job = sim.jobs[event.jobIndex]
			(job.nearestNodeIndex, dist) = findNearestNodeInGrid(sim.map, sim.grid, sim.net.fGraph.nodes, job.currentLoc)
			worker = findClosestWorker(sim,job)

			machineType = task.machineType
			closestMachine = nearestMachineToJob(sim,job,machineType)
			closestMachine.isBusy = true
			task.machineIndex = closestMachine.index
			event.machineIndex = closestMachine.index

			# assigns worker to job
			assert(job.workerIndex==nullIndex)
			job.workerIndex = worker.index
			worker.currentTask = event.task
			# move worker to job location
			job.status = jobWaitingForWorker
			worker.status = workerMovingToJob
			addEvent!(sim.eventList; parentEvent = event, eventType = moveToJob, time = sim.time, workerIndex = worker.index,jobIndex = event.jobIndex,machineIndex = event.machineIndex,task = event.task)

			# if more tasks available check for more free workers
			if !isempty(possibleQueued)
				addEvent!(sim.eventList, eventType = checkAssign, time = sim.time)
			end
		end

		##################################

	elseif eventType == moveToJob
		## move worker to job of current task
		# find location of job
		location = deepcopy(sim.jobs[event.jobIndex].currentLoc)

		# set worker as busy
		worker = sim.workers[event.workerIndex]
		worker.jobIndex = event.jobIndex

		#find distance and nearest node of job from worker
		(sim.jobs[event.jobIndex].nearestNodeIndex, dist) = findNearestNodeInGrid(sim.map, sim.grid, sim.net.fGraph.nodes, location)
		if dist>0
			changeRoute!(sim, sim.workers[event.workerIndex].route, sim.time, deepcopy(location), sim.jobs[event.jobIndex].nearestNodeIndex)
			arrivalTime = sim.workers[event.workerIndex].route.endTime
		else
			arrivalTime = sim.time
		end
		addEvent!(sim.eventList; parentEvent = event, eventType = arriveAtJob, time = arrivalTime, workerIndex = worker.index,jobIndex = event.jobIndex,machineIndex = event.machineIndex,task = event.task)
		##################################

	elseif eventType == arriveAtJob
		# process worker arriving at job. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)
		sim.workers[event.workerIndex].status = workerAtJob
		addEvent!(sim.eventList; parentEvent = event, eventType = moveJobToMachine, time = sim.time, workerIndex = event.workerIndex,jobIndex = event.jobIndex,machineIndex = event.machineIndex,task = event.task)
		##################################

	elseif eventType == moveJobToMachine
		# move worker and job to machine for processing if free machine, else free worker and add task back to queue

		# find closest machine and attach to task
		job = sim.jobs[event.jobIndex]
		job.status = jobGoingToMachine

		worker = sim.workers[event.workerIndex]
		worker.status = workerMovingToMachine
		machine = sim.machines[event.machineIndex]

		#move worker and job to machine
		changeRoute!(sim, worker.route, sim.time,machine.inputLocation, machine.nearestNodeIndex)
		addEvent!(sim.eventList; parentEvent = event, eventType = startMachineProcess, time =  worker.route.endTime,
		workerIndex = event.workerIndex, jobIndex = event.jobIndex,machineIndex = event.machineIndex, task = event.task)

		##################################

	elseif eventType == startMachineProcess
		# process worker arriving at job. If machine is free continue, else free worker and add task back to queue (this should rarely happen if at all)

		task = event.task
		machine = sim.machines[event.machineIndex]
		job = sim.jobs[event.task.jobIndex]
		worker = sim.workers[event.workerIndex]
		job.currentLoc = deepcopy(machine.inputLocation)
		worker.status = workerProcessingJob

		if !sim.batchingDict[machine.machineType]
			task.machineProcessStart = sim.time
			task.machineProcessFinish = sim.time+task.withoutWorker
			# update worker and job status
			job.status = jobAtMachine
			# release worker when no longer needed. Finish task when process is finished
			if task.withWorker != task.withoutWorker
				addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = (sim.time+task.withWorker), workerIndex = event.workerIndex)
				addEvent!(sim.eventList; parentEvent = event, eventType = finishTask, time = task.machineProcessFinish, workerIndex = event.workerIndex, jobIndex = event.jobIndex,machineIndex=event.machineIndex, task = event.task)
			else
				addEvent!(sim.eventList; parentEvent = event, eventType = finishAndRelease, time = (sim.time+task.withoutWorker), workerIndex = event.workerIndex, jobIndex = event.jobIndex,machineIndex=event.machineIndex, task = event.task)
			end
		else
			push!(machine.batchedJobIndeces,job.index)
			if (batchCheckStart(sim, machine) && !machine.processingBatch)
				machine.processingBatch = true
				processTime = batchProcessTime(sim,machine.machineType,collect(machine.batchedJobIndeces))
				for i in machine.batchedJobIndeces
					bJob = sim.jobs[i]
					bTask = bJob.tasks[bJob.taskIndex]
					bTask.machineProcessStart = sim.time
					bTask.machineProcessFinish = sim.time + processTime
					bJob.status = jobAtMachine
				end
				addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = (sim.time+sim.setupTimesDict[machine.machineType]), workerIndex = event.workerIndex)
				addEvent!(sim.eventList; parentEvent = event, eventType = finishBatch, time = sim.time + processTime, machineIndex=machine.index)
			else
				job.status = jobBatched
				machine.isBusy = false
				addEvent!(sim.eventList; parentEvent = event, eventType = releaseWorker, time = (sim.time+task.withWorker), workerIndex = event.workerIndex)
			end
		end
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
		machine = sim.machines[event.machineIndex]
		job.workerIndex=nullIndex
		job.status = jobProcessed
		job.currentLoc = deepcopy(machine.outputLocation)
		task=event.task

		assert(!task.isComplete)
		task.isComplete = true
		machine.isBusy = false

		sim.numCompletedTasks+=1
		# if no more tasks, complete job, else add next task to queue
		job.taskIndex +=1
		if job.taskIndex>length(job.tasks)
			assert(!job.finished)
			job.finished = true
			sim.numCompletedJobs+=1
			delete!(sim.currentJobs, job)
		else
			addEvent!(sim.eventList, job.tasks[job.taskIndex], event.time)
		end

		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)
		##################################

	elseif eventType == finishAndRelease
		# reset worker for further use
		worker = sim.workers[event.workerIndex]
		worker.status = workerIdle
		worker.jobIndex = nullIndex
		worker.currentTask=FactoryTask()

		# move worker and job to machine for processing if free machine, else free worker and add task back to queue
		job = sim.jobs[event.jobIndex]
		machine = sim.machines[event.machineIndex]
		job.workerIndex=nullIndex
		job.status = jobProcessed
		job.currentLoc = deepcopy(machine.outputLocation)
		task=event.task

		assert(!task.isComplete)
		task.isComplete = true
		machine.isBusy = false

		sim.numCompletedTasks+=1
		# if no more tasks, complete job, else add next task to queue
		job.taskIndex +=1
		if job.taskIndex>length(job.tasks)
			assert(!job.finished)
			job.finished = true
			sim.numCompletedJobs+=1
			delete!(sim.currentJobs, job)
		else
			addEvent!(sim.eventList, job.tasks[job.taskIndex], event.time)
		end

		addEvent!(sim.eventList; parentEvent = event, eventType = checkAssign, time = sim.time)
		##################################

	elseif eventType == finishBatch
		# move worker and job to machine for processing if free machine, else free worker and add task back to queue
		machine = sim.machines[event.machineIndex]
		machine.processingBatch =false
		for i in machine.batchedJobIndeces
			bJob = sim.jobs[i]
			bJob.workerIndex=nullIndex
			bJob.status = jobProcessed
			bJob.currentLoc = deepcopy(machine.outputLocation)


			task=bJob.tasks[bJob.taskIndex]
			assert(!task.isComplete)
			task.isComplete = true
			sim.numCompletedTasks+=1

			# if no more tasks, complete job, else add next task to queue
			bJob.taskIndex +=1
			if bJob.taskIndex>length(bJob.tasks)
				assert(!bJob.finished)
				bJob.finished = true
				sim.numCompletedJobs+=1
				delete!(sim.currentJobs, bJob)
			else
				addEvent!(sim.eventList, bJob.tasks[bJob.taskIndex], event.time)
			end
		end
		machine.isBusy = false
		machine.batchedJobIndeces = Set()
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
	worker.route.endLoc = deepcopy(sim.workerStartingLocation)
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


	sim.workers = readWorkersFile(simFilePath("workers"))
	(sim.productOrders, sim.startTime, sim.workerStartingLocation) = readProductOrdersFile(simFilePath("productOrders"))
	sim.time = sim.startTime
	(sim.machines, sim.batchingDict, sim.setupTimesDict, sim.maxBatchSizeDict) = readMachinesFile(simFilePath("machines"))
	sim.productDict = readProductDictFile(simFilePath("productDict"))
	sim.jobs = decomposeOrder(sim.workerStartingLocation, sim.productOrders,sim.productDict)
	(optimgraph, optimnodes, optimarcs, nodeLookup) =createNetworkGraph(sim.jobs)
	println(optimarcs .|> a-> a.index)
	sim.batchesDict = basicBatching(sim, optimnodes)
	batchGraph!(optimgraph, optimarcs, robot, sim, nodeLookup)
	assert(all(j->j.releaseTime>=sim.startTime, sim.jobs))

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
		(m.nearestNodeIndex, m.nearestNodeDist) = findNearestNodeInGrid(map, grid, fGraph.nodes, m.inputLocation)
	end

	commonFNodes = sort(unique([m.nearestNodeIndex for m in sim.machines]))
	JEMSS.setCommonFNodes!(net, commonFNodes)
	# create event list
	# try to add events to eventList in reverse time order, to reduce sorting required
	sim.eventList = Vector{Event}(0)

	# add first task in each job to event list
	for j in sim.jobs
		addEvent!(sim.eventList, j.tasks[1], j.releaseTime)
	end


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
	(net, travel, grid, resim) = (sim.net, sim.travel, sim.grid, sim.resim)
	(sim.net, sim.travel, sim.grid, sim.resim) = (Network(), Travel(), Grid(), Resimulation())

	sim.backup = deepcopy(sim)

	(sim.net, sim.travel, sim.grid, sim.resim) = (net, travel, grid, resim)
end

# reset sim from sim.backup
function resetSim!(sim::Simulation)
	assert(!sim.backup.used)

	if sim.used
		resetJobs!(sim)

		fnames = Set(fieldnames(sim))
		fnamesDontCopy = Set([:backup, :net, :travel, :grid, :jobs]) # will not (yet) copy these fields from sim.backup to sim
		# note that sim.backup does not contain net, travel, grid, or resim
		setdiff!(fnames, fnamesDontCopy) # remove fnamesDontCopy from fnames
		for fname in fnames
			try
				setfield!(sim, fname, deepcopy(getfield(sim.backup, fname)))
			end
		end
		for w in sim.workers
			w.status = workerIdle
		end
		for m in sim.machines
			m.isBusy = false
		end

		# reset resimulation state
		sim.resim.prevEventIndex = 0

		# reset travel state
		sim.travel.recentSetsStartTimesIndex = 1
	end
end

function resetJobs!(sim::Simulation)
	assert(!sim.backup.used)

	# shorthand:
	jobs = sim.jobs
	backupJobs = sim.backup.jobs
	numJobs = length(jobs)
	nullJob = Job()
	nullTask = FactoryTask()
	jnames = Set(fieldnames(nullJob))
	tnames = Set(fieldnames(nullTask))

	assert(length(jobs) == length(backupJobs))

	# from jnames and tnames, remove fixed parameters
	jnamesFixed = Set([:index, :releaseTime, :dueTime, :nearestNodeIndex, :nearestNodeDist, :tasks])
	setdiff!(jnames, jnamesFixed)
	tnamesFixed = Set([:index, :parentIndex, :withinJobIndex, :jobIndex, :machineType,
	:withWorker, :withoutWorker])
	setdiff!(tnames, tnamesFixed)

	recentJobIndex = findlast(job -> job.releaseTime <= sim.time, jobs)
	assert(all(i -> jobs[i].status == nullJobStatus, recentJobIndex+1:numJobs))

	# reset calls that arrived before (or at) sim.time
	for jname in jnames
		if typeof(getfield(nullJob, jname)) <: Number
			for i = 1:recentJobIndex
				setfield!(jobs[i], jname, getfield(backupJobs[i], jname))
			end
		else
			for i = 1:recentJobIndex
				setfield!(jobs[i], jname, deepcopy(getfield(backupJobs[i], jname)))
			end
		end
		for i = 1:recentJobIndex
			tlength = length(jobs[i].tasks)
			for tname in tnames
				if typeof(getfield(nullTask, tname)) <: Number
					for j = 1:tlength
						setfield!(jobs[i].tasks[j], tname, getfield(backupJobs[i].tasks[j], tname))
					end
				else
					for j = 1:tlength
						setfield!(jobs[i].tasks[j], tname, deepcopy(getfield(backupJobs[i].tasks[j], tname)))
					end
				end
			end
		end
	end
end
