## Based off writeCallsFile function in JEMSS. Changed to suit factory structure
function writeOrdersFile(filename::String, startTime::Float, productOrders::Vector{ProductOrder})
	miscTable = Table("miscData", ["startTime"]; rows = [[startTime]])
	ordersTable = Table("productOrders", ["index", "product", "size", "arrivalTime", "dueTime"];
		rows = [[p.index, Int(p.product), p.size, p.arrivalTime, p.dueTime] for p in productOrders])
	writeTablesToFile(filename, [miscTable, ordersTable])
end
