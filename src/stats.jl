function getUtilisation(sim)
    ## Author: Ali ##
    ## Get the worker utilisation
    makespan = (sim.endTime-sim.startTime)
    workers = sim.workers
    timeBusy = zeros(length(workers))
    #sum total busy time
    for i = 1:length(workers)
        timeBusy[i] =+ workers[i].timeBusy
    end
    utilisation = mean(timeBusy)/makespan
return utilisation
end
