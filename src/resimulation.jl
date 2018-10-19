# load the resimulation data from the events file
# changes sim.resim.use to be false unless all checks are passed

## Unchanged functions from JEMSS ##
function initResimulation!(sim::Simulation)
	resim = sim.resim # shorthand
	assert(resim.use)
	resim.use = false # until checks have passed

	eventsFilename = sim.outputFiles["events"].path
	println("resimulating, based on events from file: ", eventsFilename)

	if !isfile(eventsFilename)
		println("cannot resimulate, events file not found")
		return
	end

	# read events file
	(events, eventsChildren, fileEnded, inputFiles, fileChecksums) = readEventsFile(eventsFilename)

	if !fileEnded
		println("cannot resimulate, events file closed before end")
		return
	end

	# check that checksum values of input files are same as in events file
	allMatch = true
	for i = 1:length(inputFiles)
		if fileChecksums[i] != sim.inputFiles[inputFiles[i]].checksum
			println(" checksum mismatch for file: ", inputFiles[i])
			allMatch = false
		end
	end
	if !allMatch
		println("cannot resimulate, input file checksums do not match those in events file")
		return
	end

	# all checks have passed, can resimulate
	resim.use = true
	resim.events = events
	resim.eventsChildren = eventsChildren
	resim.prevEventIndex = 0
	resim.timeTolerance = 1e-5 / 2 + 10*eps()
end

function resimCheckCurrentEvent!(sim::Simulation, event::Event)
	resim = sim.resim # shorthand
	assert(resim.use)

	resim.prevEventIndex += 1 # go to event after previous (should be current)

	resimEvent = resim.events[resim.prevEventIndex] # shorthand
	eventsMatch = true
	if abs(event.time - resimEvent.time) > resim.timeTolerance
		println("mismatching event time")
		eventsMatch = false
	elseif event.eventType != resimEvent.eventType
		println("mismatching event type")
		eventsMatch = false
	elseif event.workerIndex != resimEvent.workerIndex
		println("mismatching event worker index")
		eventsMatch = false
	elseif event.jobIndex != resimEvent.jobIndex
		println("mismatching event job index")
		eventsMatch = false
	elseif event.machineIndex != resimEvent.machineIndex
		println("mismatching event machine index")
		eventsMatch = false
	end
	if !eventsMatch
		@show event
		@show resimEvent
		error("resimulation event does not match current event")
	end
end
