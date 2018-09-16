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
	startLoc = JEMSS.getRouteCurrentLocation!(net, route, startTime)

	travelMode = JEMSS.getTravelMode!(travel, priority, startTime)
	assert(travelMode.index>0)
	(startFNode, startFNodeTravelTime) = getRouteNextNode!(sim, route, travelMode.index, startTime)
	startFNodeTime = startTime + startFNodeTravelTime

	(travelTime, rNodes) = JEMSS.shortestPathTravelTime(net, travelMode.index, startFNode, endFNode)

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
	route.endTime = route.endFNodeTime + JEMSS.offRoadTravelTime(travelMode, map, net.fGraph.nodes[endFNode].location, endLoc)

	# recent rArc, recent fNode, next fNode
	JEMSS.setRouteStateBeforeStartFNode!(route, startTime)

	# first rArc
	JEMSS.setRouteFirstRArc!(net, route)
end

## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function getRouteNextNode!(sim::Simulation, route::Route, travelModeIndex::Int, time::Float)

	# shorthand:
	map = sim.map
	net = sim.net
	travelModes = sim.travel.modes

	# first need to update route
	JEMSS.updateRouteToTime!(net, route, time)

	# if route already finished, return nearest node
	# also return travel time to node based on route.endLoc
	if route.endTime <= time
		nearestFNode = route.endFNode
		travelTime = JEMSS.offRoadTravelTime(travelModes[travelModeIndex], map, route.endLoc, net.fGraph.nodes[nearestFNode].location)

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
## unchanged function from JEMSS, needed here to allow use of type FactorySim.Simulation
function getNextEvent!(eventList::Vector{Event})
	return length(eventList) > 0 ? pop!(eventList) : Event()
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

	simulateFactoryEvent!(sim, event)

	if length(sim.eventList) == 0
		# simulation complete
		assert(sim.endTime == nullTime)
		assert(sim.complete == false)
		sim.endTime = sim.time
		sim.complete = true
	end
end
