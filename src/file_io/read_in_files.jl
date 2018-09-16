# Function to read read the order list and save info to the correct types
function readProductOrders(productOrderName::String)
    data = readDlmFile(productOrderName) # returns an array
    data = orderList[setdiff(1:end,1),:] # remove the first row
    n = size(productOrdersData[1:end,1])[1] # number of rows
    #Main.Juno.render(orderList)
    #Main.Juno.render(orderList[:,1])
    dueDates = convert(Array{String},data[:,3])
    # Cornverted due date to a float (# of seconds since 1970)
    dueDates = Dates.datetime2unix.(DateTime(dueDates[:,1],"d-m-y"))
    #Main.Juno.render(dueDates)
    # create orders from data in the array
    #@assert(n >= 1)
    productOrders = Vector{ProductOrder}(n)

    for i=1:n
        productOrders[i] = ProductOrder()
        productOrders[i].product = ProductType(data[i,1])
        productOrders[i].size = data[i,2]
        productOrders[i].dueTime = dueDates[i,1]
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

function readWorkersFile(filename::String)
    tables = readTablesFromFile(filename)
    table = tables["workers"]
    n = size(table.data,1) # number of workers
	assert(n >= 1)


    workers = Vector{Worker}(n)
    c = table.columns # shorthand
    for i = 1:n
        # Do we need to include more initial attributes?
        # Otherwise they can be defined within other functions
        workers[i] = Worker()
        workers[i].index = c["index"][i]
        workers[i].isBusy = c["isBusy"][i]
        workers[i].location = Location(c["locx"][i],c["locy"][i]) #set x and y location from row i
        assert(workers[i].index == i)
    end
    return workers
end

function readProductOrdersFile(filename::String)
    tables = readTablesFromFile(filename)
    table = tables["productOrders"]
    n = size(table.data,1) # number of orders
	assert(n >= 1)


    productOrders = Vector{ProductOrder}(n)
    c = table.columns # shorthand

    for i=1:n
        productOrders[i] = ProductOrder()
        productOrders[i].product = ProductType(c["productType"][i])
        productOrders[i].size = c["size"][i]
        productOrders[i].dueTime = Dates.datetime2unix.(DateTime(c["dueDate"][i],"d-m-y"))
    end
    return productOrders
end

function readMachinesFile(filename::String)
    tables = readTablesFromFile(filename)
    table = tables["machines"]
    n = size(table.data,1) # number of orders
	assert(n >= 1)

    machines = Vector{Machine}(n)
    c = table.columns # shorthand

    for i = 1:n
        machines[i] = Machine()
        machines[i].index = c["index"][i]
        machines[i].machineType = MachineType(c["machineType"][i])
        machines[i].location = Location(c["locx"][i],c["locy"][i]) #set x and y location from row i
    end
    return machines
end

function readProductDictFile(filename::String)
    tables = readTablesFromFile(filename)
    table = tables["miscData"]
    numProducts = table.columns["numProducts"][1]

    table = tables["productDict"]
    n = size(table.data,1) # number of orders
    assert(n >= 1)

    productDict = Dict{ProductType,Vector{FactoryTask}}()
    c = table.columns # shorthand


    j=0
    factTaskList = Vector{FactoryTask}()
    for i = 1:n
        if (j<c["productType"][i])
            if j!=0
                productDict[ProductType(j)]= deepcopy(factTaskList)
            end
            factTaskList = Vector{FactoryTask}()
            j=+1
        end

        task = FactoryTask()
        task.machineType = MachineType(c["machineType"][i])
        task.withWorker = c["withWorker"][i]
        task.withoutWorker = c["withoutWorker"][i]
        push!(factTaskList,task)

        if i==n
            key = c["productType"][n]
            productDict[ProductType(key)]= deepcopy(factTaskList)
        end

    end
    return productDict

end
