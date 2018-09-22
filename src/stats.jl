function getUtilisation(sim)
    ## Get the worker utilisation
    makespan = (sim.endTime-sim.startTime)
    workers = sim.workers
    timeBusy = zeros(length(workers))
    for i = 1:length(workers)
        timeBusy[i] =+ workers[i].timeBusy
    end
    utilisation = mean(timeBusy)/makespan
return utilisation
end
