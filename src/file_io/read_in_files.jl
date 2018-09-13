# Function to read read the order list and save info to the correct types
function readOrderList(productOrderName::String)
    orderList = readDlmFile(productOrderName) # returns an array
    orderList = orderList[setdiff(1:end,1),:] # remove the first row
    n = size(orderList[1:end,1])[1] # number of rows
    #Main.Juno.render(orderList)
    #Main.Juno.render(orderList[:,1])
    dueDates = convert(Array{String},orderList[:,3])
    # Cornverted due date to a float (# of seconds since 1970)
    dueDates = Dates.datetime2unix.(DateTime(dueDates[:,1],"d-m-y"))
    #Main.Juno.render(dueDates)
    # create orders from data in the array
    #@assert(n >= 1)
    orders = Vector{ProductOrder}(n)

    for i=1:n
        orders[i] = ProductOrder()
        orders[i].product = ProductType(orderList[i,1])
        orders[i].size = orderList[i,2]
        orders[i].dueTime = dueDates[i,1]
    end
    return orders
end

function readMachines(machineList::String)
    machineListData = readDlmFile(machineList)
    machineListData = machineListData[setdiff(1:end,1),:] # remove the first row
    n = size(machineListData[1:end,1])[1] # number of rows

    machines = Vector{Machine}(n)

    for i = 1:n
        machines[i] = Machine()
        machines[i].machineType = MachineType(machineListData[i,1])
        machines[i].loc = Location(machineListData[i,2],machineListData[i,3]) #set x and y location from row i
    end
    return machines
end

function readWorkers(workerList::String)
    workerListData = readDlmFile(workerList)
    workerListData = workerListData[setdiff(1:end,1),:] # remove the first row
    n = size(workerListData[1:end,1])[1] # number of rows

    workers = Vector{Worker}(n)

    for i = 1:n
        # Do we need to include more initial attributes?
        # Otherwise they can be defined within other functions
        workers[i] = Worker()
        workers[i].index = workerListData[i,1]
        workers[i].isBusy = workerListData[i,2]
        workers[i].location = Location(workerListData[i,3],workerListData[i,4]) #set x and y location from row i
    end
    return workers
end
