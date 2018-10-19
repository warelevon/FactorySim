# for generating simulation objects based on a config file

type FactConfig
	inputPath::String
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
	## Author: Ali ##
	# read gen config xml file
	rootElt = xmlFileRoot(factConfigFilename)
	#println("rootElt is:", name(rootElt)) # Debugging
	@assert(name(rootElt) == "simConfig", string("xml root has incorrect name: ", name(rootElt)))

	factConfig = FactConfig()
	factConfig.inputPath = abspath(eltContentInterpVal(rootElt, "inputPath"))
	factConfig.mode = eltContent(rootElt, "mode")

	# input filenames
	simFilesElt = findElt(rootElt, "simFiles")
	simFilePath(filename::String) = joinpath(factConfig.inputPath, eltContent(simFilesElt, filename))
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


function runFactConfig(factConfigFilename::String; overwriteInputPath::Bool = false)
	## Author: Ali ##
	factConfig = readFactConfig(factConfigFilename)

	#if isdir(factConfig.inputPath) && !overwriteInputPath
	#	println("input path already exists: ", factConfig.inputPath)
	#	print("Delete folder contents and continue anyway? (y = yes): ")
	#	response = chomp(readline())
	#	if response != "y"
	#		println("stopping")
	#		return
	#	else
	#		overwriteInputPath = true
	#	end
	#end
	#if isdir(factConfig.inputPath) && overwriteInputPath
	#	println("Deleting folder contents: ", factConfig.inputPath)
	#	rm(factConfig.inputPath; recursive=true)
	#end
	#if !isdir(factConfig.inputPath)
	#	mkdir(factConfig.inputPath)
	#end

	println("Generation mode: ", factConfig.mode)
	# make productOrders
	productOrders = makeOrders(factConfig) ## generated from function

	# save all
	println("Saving input to: ", factConfig.inputPath)
	FactorySim.writeOrdersFile(factConfig.productOrdersFileName, factConfig.startTime, productOrders)
end

## Based off JEMSS makeCalls function, changed to orders for our project structure
function makeOrders(factConfig::FactConfig)
	## Author: Ali ##
	productOrders = Vector{ProductOrder}(factConfig.numOrders)

	# factConfig.startTime is the the number of seconds after 00:00 today
	currentTime = floor(Dates.DateTime(Dates.now()), Dates.Hour(24)) + Dates.Second(factConfig.startTime)
	# first call will arrive at genConfig.startTime + rand(genConfig.interarrivalTimeDistrRng)
	for i = 1:factConfig.numOrders
		currentTime += Dates.Second(round(rand(factConfig.interarrivalTimeDistrRng)*24*3600)) # apply time step (exponential dist)
		productOrders[i] = ProductOrder()
		productOrders[i].index = i
		productOrders[i].product = ProductType(rand(factConfig.productOrderTypeDistrRng)) #categorical dist
		productOrders[i].size = (rand(factConfig.productOrdersizeDistrRng)) #discrete uniform dist
		productOrders[i].releaseTime = Dates.datetime2unix.(currentTime)
		# Current time plus (dueTime-releaseTime)
		productOrders[i].dueTime = Dates.datetime2unix.(currentTime + Dates.Second(round(rand(factConfig.dueTimeDistrRng)*24*3600))) #triangular dist
	end
	return productOrders
end
