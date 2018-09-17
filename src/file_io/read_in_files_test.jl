using FactorySim
using JEMSS

# Run the pre config scripts then the block of code corresponding to the
# function that you want to test.

path =  "C:\\Users\\dd\\.julia\\v0.6\\FactorySim\\example\\input"
productOrderName = joinpath(path, "productOrders.csv")
testOrderList = readProductOrdersFile(productOrderName);
Main.Juno.render(testOrderList)

path =  "C:\\Users\\dd\\.julia\\v0.6\\FactorySim\\example\\input"
machineListName = joinpath(path, "Machines.csv")
testMachineList = readMachines(machineListName);
Main.Juno.render(testMachineList)

path =  "C:\\Users\\dd\\.julia\\v0.6\\FactorySim\\example\\input"
workerListName = joinpath(path, "Workers.csv")
testWorkerList = readWorkers(workerListName);
Main.Juno.render(testWorkerList)
