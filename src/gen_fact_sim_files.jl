# for generating simulation objects based on a config file

type FactConfig
	outputPath::String
	mode::String

	# Output filenames
	factoryFilename::String
	productOrdersFileName::String

	# counts
	numOrders::Int
	numNodes::Int # total number of nodes
	maxConnectDist::Float # max connection distance of nodes

	# misc values
	startTime::Float

	# distributions realted to orders
	interarrivalTimeDistrRng::DistrRng
	productOrderTypeDistrRng::DistrRng
	productOrdersizeDistrRng::DistrRng
	dueTimeDistrRng::DistrRng

	FactConfig() = new("","","","",nullIndex, nullIndex, nullDist, nullTime)
end

## Based off readGenConfig in JEMSS with changes due to separate problem structure
function readFactConfig(factConfigFilename::String)
	# read gen config xml file
	rootElt = xmlFileRoot(factConfigFilename)
	println("rootElt is:", name(rootElt)) # Debugging
	@assert(name(rootElt) == "simConfig", string("xml root has incorrect name: ", name(rootElt)))

	factConfig = FactConfig()
	factConfig.outputPath = abspath(eltContentInterpVal(rootElt, "outputPath"))
	factConfig.mode = eltContent(rootElt, "mode")

	# output filenames
	simFilesElt = findElt(rootElt, "simFiles")
	simFilePath(filename::String) = joinpath(factConfig.outputPath, eltContent(simFilesElt, filename))
	factConfig.productOrdersFileName = simFilePath("productOrders")

	# read sim parameters
	simElt = findElt(rootElt, "sim")

	# call distributions and random number generators
	orderDistrsElt = findElt(simElt, "productOrderDistributions")
	function orderDistrsEltContent(distrName::String)
		distrElt = findElt(orderDistrsElt, distrName)
		distr = eltContentVal(distrElt)
		seedAttr = attribute(distrElt, "seed")
		seed = (seedAttr == nothing ? nullIndex : eval(parse(seedAttr)))
		return DistrRng(distr; seed = seed)
	end

	factConfig.interarrivalTimeDistrRng = orderDistrsEltContent("interarrivalTime")
	factConfig.productOrderTypeDistrRng = orderDistrsEltContent("productOrderType")
	factConfig.productOrdersizeDistrRng = orderDistrsEltContent("productOrderSize")
	factConfig.dueTimeDistrRng = orderDistrsEltContent("dueTime")
	# number of orders
	factConfig.numOrders = eltContentVal(simElt, "numOrders")

	# misc values
	factConfig.startTime = eltContentVal(simElt, "startTime")
	assert(factConfig.startTime >= 0)

	return factConfig
end


function runFactConfig(factConfigFilename::String; overwriteOutputPath::Bool = false)
	factConfig = readFactConfig(factConfigFilename)

	if isdir(factConfig.outputPath) && !overwriteOutputPath
		println("Output path already exists: ", factConfig.outputPath)
		print("Delete folder contents and continue anyway? (y = yes): ")
		response = chomp(readline())
		if response != "y"
			println("stopping")
			return
		else
			overwriteOutputPath = true
		end
	end
	if isdir(factConfig.outputPath) && overwriteOutputPath
		println("Deleting folder contents: ", factConfig.outputPath)
		rm(factConfig.outputPath; recursive=true)
	end
	if !isdir(factConfig.outputPath)
		mkdir(factConfig.outputPath)
	end

	println("Generation mode: ", factConfig.mode)
	# make productOrders
	productOrders2 = makeOrders(factConfig) ## generated from function

	# save all
	println("Saving output to: ", factConfig.outputPath)
	FactorySim.writeOrdersFile(factConfig.productOrdersFileName, factConfig.startTime, productOrders2)
end

## Based off JEMSS makeCalls function, changed to orders for our project structure
function makeOrders(factConfig::FactConfig)
	productOrders2 = Vector{ProductOrder}(factConfig.numOrders)

	currentTime = factConfig.startTime
	# first call will arrive at genConfig.startTime + rand(genConfig.interarrivalTimeDistrRng)
	for i = 1:factConfig.numOrders
		currentTime += rand(factConfig.interarrivalTimeDistrRng) # apply time step (exponential dist)

		productOrders2[i] = ProductOrder()
		productOrders2[i].index = i
		productOrders2[i].product = ProductType(rand(factConfig.productOrderTypeDistrRng)) #categorical dist
		productOrders2[i].size = (rand(factConfig.productOrdersizeDistrRng)) #discrete uniform dist
		productOrders2[i].arrivalTime = currentTime
		productOrders2[i].dueTime = currentTime + rand(factConfig.dueTimeDistrRng) #triangular dist
	end
	return productOrders2
end
