using FactorySim
using JEMSS
sim = FactorySim.Simulation()
sim.workerStartingLocation=startingLoc
event=FactorySim.Event()
for i = 1:3
    push!(sim.workers,Worker())
    sim.workers[i].index=i
end
checkFreeWorker!(sim)
sim.workers[1].status=workerProcessingJob
worker = findClosestWorker(filter(w -> w.status==workerIdle,sim.workers),sim.workerStartingLocation)
sim
event.task.index = 4
for i = 1:3
push!(sim.queuedTaskList,FactoryTask())
sim.queuedTaskList[i].index=i
end
push!(sim.queuedTaskList,event.task)
