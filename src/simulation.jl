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
		addEvent!(sim.eventList; parentEvent = event, eventType = checkAvailableWorker, time = sim.time)
		##################################

	elseif eventType == checkAvailableWorker
		# if a worker is available assign task to worker
		checkFreeWorker!(sim)
		if sim.workerFree
			addEvent!(sim.eventList; parentEvent = event, eventType = AssignAvailableWorker, time = sim.time)
		end
		##################################

	elseif eventType == AssignClosestAvailableWorker
		# add released task to the queue and check for available workers
		worker = findClosestWorker(filter(w -> !w.isBusy,sim.workers),event.task)
		if sim.workerFree
			addEvent!(sim.eventList; parentEvent = event, eventType = moveToBatch, time = sim.time, workerIndex = worker.index,batchIndex = event.batchIndex)
		end
		##################################9988888887777777777777777777777777
	elseif eventType == moveToBatch
		# add released task to the queue and check for available workers
		worker = findClosestWorker(filter(w -> !w.isBusy,sim.workers),event.task)
		if sim.workerFree
			addEvent!(sim.eventList; parentEvent = event, eventType = moveToBatch, time = sim.time, workerIndex = worker.index,batchIndex = event.batchIndex)
		end
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
		end
	end
end

function findClosestWorker(workers::Vector{Worker},task::FactoryTask)
	return workers[1]
end
