global animConnections = Dict{Int,WebSocket}() # store open connections
global animConfigFilenames = Vector{String}() # store filenames between animation request and start
global animPort = nullIndex # localhost port for animation, to be set



function animFactSetIcons(client::WebSocket)
	messageDict = JEMSS.createMessageDict("set_icons")
	pngFileUrl(filename) = string("data:image/png;base64,", filename |> read |> base64encode)
	iconPath = joinpath(@__DIR__, "..", "..", "assets", "animation", "icons")
	icons = JSON.parsefile(joinpath(iconPath, "icons.json"))
	# set iconUrl for each icon
	for (name, icon) in icons
		icon["options"]["iconUrl"] = pngFileUrl(joinpath(iconPath, string(name, ".png")))
	end
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

function animAddMachines(client::WebSocket, sim::Simulation)
	messageDict = JEMSS.createMessageDict("add_machine")
	for m in sim.machines
		messageDict["hospital"] = h
		write(client, json(messageDict))
	end
	delete!(messageDict, "hospital")(messageDict, "station")
end

function animAddWorkers!(client::WebSocket, sim::Simulation)
	messageDict = JEMSS.createMessageDict("add_worker")
	for worker in sim.workers
		worker.location = JEMSS.getRouteCurrentLocation!(sim.net, worker.route, sim.startTime)
		messageDict["worker"] = worker
		write(client, json(messageDict))
	end
end

# write frame updates to client
function updateFrame!(client::WebSocket, sim::Simulation, time::Float)

	# check which ambulances have moved since last frame
	# need to do this before showing call locations
	messageDict = createMessageDict("move_ambulance")
	for amb in sim.ambulances
		ambLocation = getRouteCurrentLocation!(sim.net, amb.route, time)
		if !isSameLocation(ambLocation, amb.currentLoc)
			amb.currentLoc = ambLocation
			amb.movedLoc = true
			# move ambulance
			messageDict["ambulance"] = amb
			write(client, json(messageDict))
		else
			amb.movedLoc = false
		end
	end
	delete!(messageDict, "ambulance")

	# determine which calls to remove, update, and add
	# need to do this after finding new ambulance locations
	# shorthand variable names:
	previousCalls = sim.previousCalls
	currentCalls = sim.currentCalls
	removeCalls = setdiff(previousCalls, currentCalls)
	updateCalls = intersect(previousCalls, currentCalls)
	addCalls = setdiff(currentCalls, previousCalls)
	changeMessageDict!(messageDict, "remove_call")
	for call in removeCalls
		call.currentLoc = Location()
		messageDict["call"] = call
		write(client, json(messageDict))
	end
	changeMessageDict!(messageDict, "move_call")
	for call in updateCalls
		updateCallLocation!(sim, call)
		messageDict["call"] = call
		write(client, json(messageDict))
	end
	changeMessageDict!(messageDict, "add_call")
	for call in addCalls
		call.currentLoc = deepcopy(call.location)
		call.movedLoc = false
		updateCallLocation!(sim, call)
		messageDict["call"] = call
		write(client, json(messageDict))
	end
	sim.previousCalls = copy(sim.currentCalls) # update previousCalls
end

# update call current location
function updateJobLocation!(sim::Simulation, job::Job)
	# consider moving call if the status indicates location other than call origin location
	if call.status == callGoingToHospital || call.status == callAtHospital
		amb = sim.ambulances[call.ambIndex]
		call.movedLoc = amb.movedLoc
		if amb.movedLoc
			call.currentLoc = amb.currentLoc
		end
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
	sim = initSimulation(configFilename; allowResim = true)
	println("...initialised")

	# set map
	messageDict = createMessageDict("set_map_view")
	messageDict["map"] = sim.map
	write(client, json(messageDict))

	# set sim start time
	messageDict = createMessageDict("set_start_time")
	messageDict["time"] = sim.startTime
	write(client, json(messageDict))

	animSetIcons(client) # set icons before adding items to map
	animAddNodes(client, sim.net.fGraph.nodes)
	animAddArcs(client, sim.net) # add first, should be underneath other objects
	animSetArcSpeeds(client, sim.map, sim.net)
	animAddBuildings(client, sim)
	animAddAmbs!(client, sim)

	messageDict = createMessageDict("")
	while true
		msg = read(client) # waits for message from client
		msgString = decodeMessage(msg)
		(msgType, msgData) = parseMessage(msgString)

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
			animAddAmbs!(client, sim)

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
