using FactorySim
using JEMSS
sim = FactorySim.Simulation()
event=FactorySim.Event()
for i = 1:3
    push!(sim.workers,Worker())
    sim.workers[i].index=i
end
checkFreeWorker!(sim)
sim.workers[1].isBusy=true
worker = findClosestWorker(filter(w -> !w.isBusy,sim.workers),event.task)
sim
