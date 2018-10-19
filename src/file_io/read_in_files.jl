# all file read functions are based on a similar to form to their JEMSS counterparts
function readWorkersFile(filename::String)
    ## Author: Ali ##
    tables = readTablesFromFile(filename)
    table = tables["workers"]
    n = size(table.data,1) # number of workers
	assert(n >= 1)


    workers = Vector{Worker}(n)
    c = table.columns # shorthand
    # read in worker data
    for i = 1:n
        workers[i] = Worker()
        workers[i].index = c["index"][i]
        workers[i].currentLoc = Location(c["locx"][i],c["locy"][i]) #set x and y location from row i
        assert(workers[i].index == i)
    end
    return workers
end

function readProductOrdersFile(filename::String)
    ## Author: Ali ##
    tables = readTablesFromFile(filename)

    # read various data around orders
    table = tables["miscData"]
    startTime = Dates.datetime2unix.(DateTime(table.columns["startTime"][1],"d-m-yTH:M:S"))/60/60/24
    startingLocation = Location()
    startingLocation.x = table.columns["startLocx"][1]
    startingLocation.y = table.columns["startLocy"][1]

    table = tables["productOrders"]
    n = size(table.data,1) # number of orders
	assert(n >= 1)


    productOrders = Vector{ProductOrder}(n)
    c = table.columns # shorthand

    # read in orders
    for i=1:n
        productOrders[i] = ProductOrder()
        productOrders[i].product = ProductType(c["productType"][i])
        productOrders[i].size = c["size"][i]
        productOrders[i].releaseTime = Dates.datetime2unix.(DateTime(c["releaseTime"][i],"d-m-yTH:M:S"))/60/60/24 #TH:M:S.s
        productOrders[i].dueTime = Dates.datetime2unix.(DateTime(c["dueTime"][i],"d-m-yTH:M:S"))/60/60/24 #TH:M:S.s
        assert(productOrders[i].dueTime > productOrders[i].releaseTime) # Make sure that each order is due after it arrives
    end
    return productOrders, startTime, startingLocation
end

function readMachinesFile(filename::String)
    ## Author: Ali ##
    tables = readTablesFromFile(filename)

    # load different machine types
    table = tables["machineTypes"]
    m = size(table.data,1)
	assert(m >= 1)
    c = table.columns

    # initiate dictionaries for storing machine type data
    batchingDict = Dict{MachineType,Bool}()
    batchingDict[nullMachineType] = false
    setupTimeDict = Dict{MachineType,Float}()
    setupTimeDict[nullMachineType] = nullTime
    maxBatchDict = Dict{MachineType,Integer}()
    maxBatchDict[nullMachineType] = nullIndex

    # populating dictionaries
    for i = 1:m
        batchingDict[MachineType(i)] = Bool(c["isBatched"][i])
        setupTimeDict[MachineType(i)] = c["setupTimes"][i]/60/24
        maxBatchDict[MachineType(i)] = c["maxBatchSize"][i]
    end

    table = tables["machines"]
    n = size(table.data,1) # number of orders
	assert(n >= 1)

    machines = Vector{Machine}(n)
    c = table.columns # shorthand

    # reading in individual machines
    for i = 1:n
        machines[i] = Machine()
        machines[i].index = c["index"][i]
        machines[i].machineType = MachineType(c["machineType"][i])
        machines[i].location = Location(c["locx"][i],c["locy"][i]) #set x and y location from row i
        machines[i].inputLocation = Location(c["ilocx"][i],c["ilocy"][i]) #set x and y location from row i
        machines[i].outputLocation = Location(c["olocx"][i],c["olocy"][i]) #set x and y location from row i
    end
    return machines, batchingDict, setupDict, maxBatchDict
end

function readProductDictFile(filename::String)
    ## Author: Ali ##
    tables = readTablesFromFile(filename)
    dictTable = tables["productDict"]
    m = size(dictTable.data,1) # number of orders
    assert(m >= 1)
    productDict = Dict{ProductType,Vector{FactoryTask}}()
    # load each task list for each product type
    for k=1:m
        product = dictTable.columns["productName"][k]
        key = ProductType(dictTable.columns["productType"][k])
        table = tables[product]
        n = size(table.data,1) # number of tasks
        assert(n >= 1)
        c = table.columns # shorthand
        taskList = Vector{FactoryTask}(n)
        # populate each task list
        for i = 1:n
            taskList[i] = FactoryTask()
            taskList[i].machineType = MachineType(c["machineType"][i])
            taskList[i].withWorker = c["withWorker"][i]/60/24
            taskList[i].withoutWorker = c["withoutWorker"][i]/60/24
        end
        productDict[key]= deepcopy(factTaskList)
    end
    return productDict
end
