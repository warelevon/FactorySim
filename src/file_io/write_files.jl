## All functions in this file are slight edits of the respective functionss from JEMSS in write_sim_files.jl

function openOutputFiles!(sim::Simulation)
	## Author: Ali ##
	if !sim.writeOutput; return; end

	println("output path: ", sim.outputPath)
	outputFilePath(name::String) = sim.outputFiles[name].path

	# create output path if it does not already exist
	if !isdir(sim.outputPath)
		mkdir(sim.outputPath)
	end

	# open output files for writing
	# currently, only need to open events file
	# otherwise, existing events file is used for resimulation
	sim.outputFiles["events"].iostream = open(outputFilePath("events"), "w")
	sim.eventsFileIO = sim.outputFiles["events"].iostream # shorthand

	# save checksum of input files
	inputFiles = sort([name for (name, file) in sim.inputFiles])
	fileChecksumStrings = [string("'", sim.inputFiles[name].checksum, "'") for name in inputFiles]
	writeTablesToFile!(sim.eventsFileIO, Table("inputFiles", ["name", "checksum"]; cols = [inputFiles, fileChecksumStrings]))

	# save events with a key, to reduce file size
	eventTypes = instances(EventType)
	eventKeys = [Int(eventType) for eventType in eventTypes]
	eventNames = [string(eventType) for eventType in eventTypes]
	writeTablesToFile!(sim.eventsFileIO, Table("eventDict", ["key", "name"]; cols = [eventKeys, eventNames]))

	# write events table name and header
	writeDlmLine!(sim.eventsFileIO, "events")
	writeDlmLine!(sim.eventsFileIO, "index", "parentIndex", "time", "eventKey", "workerIndex", "jobIndex", "macIndex","eventListSize")
end

function writeEventToFile!(sim::Simulation, event::Event)
	## Author: Ali ##
	if !sim.writeOutput; return; end

	writeDlmLine!(sim.eventsFileIO, event.index, event.parentIndex, @sprintf("%0.5f", event.time), Int(event.eventType), event.workerIndex, event.jobIndex, event.machineIndex, length(sim.eventList))

end

function closeOutputFiles!(sim::Simulation)
	if !sim.writeOutput; return; end

	writeDlmLine!(sim.eventsFileIO, "end")
	close(sim.eventsFileIO)

end
