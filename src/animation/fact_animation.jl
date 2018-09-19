global animConnections = Dict{Int,WebSocket}() # store open connections
global animConfigFilenames = Vector{String}() # store filenames between animation request and start
global animPort = nullIndex # localhost port for animation, to be set



function animSetIcons(client::WebSocket, sim::Simulation)
	pngFileUrl(filename) = string("data:image/png;base64,", filename |> read |> base64encode)
	iconPath = joinpath(@__DIR__, "..", "..", "assets", "animation", "icons")
	icons = JSON.parsefile(joinpath(iconPath, "icons.json"))
	# set iconUrl for each icon
	for (name, icon) in icons
		if name =="background"
			bg = sim.background
			map = sim.map
			(bg.xMin,bg.xMax,bg.yMin,bg.yMax) = (map.xMin-0.15,map.xMax+0.15,map.yMin-0.15,map.yMax+0.15)

			sim.background.imgUrl =  pngFileUrl(joinpath(iconPath, string(name, ".png")))
			animSetBackground(client, sim)
		else
			icon["options"]["iconUrl"] = pngFileUrl(joinpath(iconPath, string(name, ".png")))
		end
	end
	messageDict = JEMSS.createMessageDict("set_icons")
	merge!(messageDict, icons)
	write(client, json(messageDict))
end

function fact_animate(; port::Int = 8001, configFilename::String = "", openWindow::Bool = true)
	global animConfigFilenames
	if runAnimServer(port)
		if configFilename != ""
			push!(animConfigFilenames, configFilename)
		end
		openWindow ? openLocalhost(port) : println("waiting for window with port $port to be opened")
	end
end
function animSetBackground(client::WebSocket, sim::Simulation)
	messageDict = JEMSS.createMessageDict("set_background")
	messageDict["background"] = sim.background
	write(client, json(messageDict))
	delete!(messageDict, "background")
end
function animAddMachines(client::WebSocket, sim::Simulation)
	messageDict = JEMSS.createMessageDict("add_machine")
	for m in sim.machines
		messageDict["machine"] = m
		write(client, json(messageDict))
	end
	delete!(messageDict, "machine")
end

function animAddWorkers!(client::WebSocket, sim::Simulation)
	messageDict = JEMSS.createMessageDict("add_worker")
	for worker in sim.workers
		worker.currentLoc = JEMSS.getRouteCurrentLocation!(sim.net, worker.route, sim.startTime)
		messageDict["worker"] = worker
		write(client, json(messageDict))
	end
end

# write frame updates to client
function updateFrame!(client::WebSocket, sim::Simulation, time::Float)

	# check which ambulances have moved since last frame
	# need to do this before showing call locations
	workers = sim.workers
	jobs = sim.jobs
	machines = sim.machines
	messageDict = JEMSS.createMessageDict("move_worker")
	for worker in workers
		workerLocation = JEMSS.getRouteCurrentLocation!(sim.net, worker.route, time)
		if !JEMSS.isSameLocation(workerLocation, worker.currentLoc)
			worker.currentLoc = deepcopy(workerLocation)
			worker.movedLoc = true
			# move ambulance
			messageDict["worker"] = worker
			write(client, json(messageDict))
		else
			worker.movedLoc = false
		end
	end
	delete!(messageDict, "worker")

	# determine which calls to remove, update, and add
	# need to do this after finding new ambulance locations
	# shorthand variable names:
	previousJobs = sim.previousJobs
	currentJobs = sim.currentJobs
	removeJobs = setdiff(previousJobs, currentJobs)
	updateJobs = intersect(previousJobs, currentJobs)
	addJobs = setdiff(currentJobs, previousJobs)
	JEMSS.changeMessageDict!(messageDict, "remove_job")
	for job in removeJobs
		job.currentLoc = Location()
		messageDict["job"] = job
		write(client, json(messageDict))
	end
	JEMSS.changeMessageDict!(messageDict, "move_job")
	for job in updateJobs
		updateJobLocation!(sim, job)
		messageDict["job"] = job
		write(client, json(messageDict))
	end
	JEMSS.changeMessageDict!(messageDict, "add_job")
	for job in addJobs
		job.movedLoc = false
		updateJobLocation!(sim, job)
		messageDict["job"] = job
		write(client, json(messageDict))
	end
	sim.previousJobs = deepcopy(sim.currentJobs) # update previousCalls
end

# update call current location
function updateJobLocation!(sim::Simulation, job::Job)
	# consider moving job if the status indicates worker moving job
	if job.status == jobGoingToMachine
		worker = sim.workers[job.workerIndex]
		job.movedLoc = worker.movedLoc
		if worker.movedLoc
			job.currentLoc = deepcopy(worker.currentLoc)
		end
	elseif job.status == jobAtMachine
		task = job.tasks[job.taskIndex]
		machine = sim.machines[task.machineIndex]
		oLoc = deepcopy(machine.outputLocation)
		iLoc = deepcopy(machine.inputLocation)
		taskProg = sim.time - task.machineProcessStart
		taskTotal = task.machineProcessFinish - task.machineProcessStart
		taskPerc = taskProg/taskTotal
		job.currentLoc.x = iLoc.x + (taskPerc * (oLoc.x-iLoc.x))
		job.currentLoc.y = iLoc.y + (taskPerc * (oLoc.y-iLoc.y))
		job.movedLoc = true
	end
end

wsh = WebSocketHandler() do req::Request, client::WebSocket
	global animConnections, animConfigFilenames

	animConnections[client.id] = client
	println("Client ", client.id, " connected")

	# get oldest filename from animConfigFilenames, or select file now
	configFilename = (length(animConfigFilenames) > 0 ? shift!(animConfigFilenames) : selectXmlFile())
	println("Running from config: ", configFilename)

	println("Initialising simulation...")
	sim = initSimulation(configFilename)
	println("...initialised")

	# set map
	messageDict = JEMSS.createMessageDict("set_map_view")
	messageDict["map"] = sim.map
	write(client, json(messageDict))

	# set sim start time
	messageDict = JEMSS.createMessageDict("set_start_time")
	messageDict["time"] = sim.startTime
	write(client, json(messageDict))

	animSetIcons(client, sim) # set icons before adding items to map
	JEMSS.animAddNodes(client, sim.net.fGraph.nodes)
	JEMSS.animAddArcs(client, sim.net) # add first, should be underneath other objects
	JEMSS.animSetArcSpeeds(client, sim.map, sim.net)
	animAddMachines(client, sim)
	animAddWorkers!(client, sim)

	messageDict = JEMSS.createMessageDict("")
	while true
		msg = read(client) # waits for message from client
		msgString = JEMSS.decodeMessage(msg)
		(msgType, msgData) = JEMSS.parseMessage(msgString)

		if msgType == "prepare_next_frame"
			simTime = Float(msgData[1])
			simulateToTime!(sim, simTime)
			messageDict["time"] = simTime
			JEMSS.writeClient!(client, messageDict, "prepared_next_frame")

		elseif msgType == "get_next_frame"
			simTime = Float(msgData[1])
			updateFrame!(client, sim, simTime) # show updated amb locations, etc
			if !sim.complete
				messageDict["time"] = simTime
				JEMSS.writeClient!(client, messageDict, "got_next_frame")
			else
				# no events left, finish animation
				JEMSS.writeClient!(client, messageDict, "got_last_frame")
			end

		elseif msgType == "pause"

		elseif msgType == "stop"
			# reset
			resetSim!(sim)
			animAddWorkers!(client, sim)

		elseif msgType == "update_icons"
			try
				animSetIcons(client)
			catch e
				warn("Could not update animation icons")
				warn(e)
			end

		elseif msgType == "disconnect"
			close(client)
			println("Client ", client.id, " disconnected")
			break
		else
			error("Unrecognised message: ", msgString)
		end
	end
end

# start the animation, open a browser window for it
# can set the port for the connection, and the simulation config filename
# openWindow = false prevents a browser window from opening automatically, will need to open manually
function animate(; port::Int = 8001, configFilename::String = "", openWindow::Bool = true)
	global animConfigFilenames
	if runAnimServer(port)
		if configFilename != ""
			push!(animConfigFilenames, configFilename)
		end
		openWindow ? JEMSS.openLocalhost(port) : println("waiting for window with port $port to be opened")
	end
end

# creates and runs server for given port
# returns true if server is running, false otherwise
function runAnimServer(port::Int)
	# check if port already in use
	global animPort
	if port == animPort && port != nullIndex
		return true # port already used for animation
	elseif animPort != nullIndex
		println("use port $animPort instead")
		return false
	end
	try
		socket = connect(port)
		if socket.status == 3 # = open
			println("port $port is already in use, try another")
			return false
		end
	end

	# create and run server
	onepage = readstring("$sourcePath/animation/index.html")
	httph = HttpHandler() do req::Request, res::Response
		Response(onepage)
	end
	server = Server(httph, wsh)
	@async run(server, port)
	animPort = port
	println("opened port $animPort, use this for subsequent animation windows")
	return true
end

# JSON.lower for various types, to reduce length of string returned from json function
JSON.lower(w::Worker) = Dict("index" => w.index, "currentLoc" => w.currentLoc, "status" => w.status)
JSON.lower(j::Job) = Dict("index" => j.index, "currentLoc" => j.currentLoc)
JSON.lower(m::Machine) = Dict("index" => m.index, "location" => m.location, "machineType" => m.machineType)
