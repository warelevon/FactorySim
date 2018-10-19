## Based off writeCallsFile function in JEMSS. Changed to suit factory structure
function writeOrdersFile(filename::String, startTime::Float, productOrders::Vector{ProductOrder})
	## Author: Ali ##
	miscTable = Table("miscData", ["startTime"]; rows = [[Dates.format(Dates.unix2datetime(productOrders[1].releaseTime+startTime),"dd-mm-yyyyTHH:MM:SS")]])
	ordersTable = Table("productOrders", ["index", "productType", "size", "releaseTime", "dueTime"];
		rows = [[p.index, Int(p.product), p.size, Dates.format(Dates.unix2datetime(p.releaseTime),"dd-mm-yyyyTHH:MM:SS"), Dates.format(Dates.unix2datetime(p.dueTime),"dd-mm-yyyyTHH:MM:SS")] for p in productOrders])
	writeTablesToFile(filename, [miscTable, ordersTable])
end
