using FactorySim
using JEMSS

# Run the pre config scripts then the block of code corresponding to the
# function that you want to test.

path =  @__DIR__
productOrderName = joinpath(path, "ProductOrder.csv")
testOrderList = readOrderList(productOrderName);
Main.Juno.render(testOrderList)

path =  @__DIR__
machineListName = joinpath(path, "Machines.csv")
testMachineList = readMachines(machineListName);
Main.Juno.render(testMachineList)

path =  @__DIR__
workerListName = joinpath(path, "Workers.csv")
testWorkerList = readMachines(workerListName);
Main.Juno.render(testWorkerList)
