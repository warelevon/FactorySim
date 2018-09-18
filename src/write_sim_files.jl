## Based off writeCallsFile function in JEMSS. Changed to suit factory structure
function writeOrdersFile(filename::String, startTime::Float, productOrders::Vector{ProductOrder})
	miscTable = Table("miscData", ["startTime"]; rows = [[startTime]])
	ordersTable = Table("productOrders2", ["index", "product", "size", "releaseTime", "dueTime"];
		rows = [[p.index, Int(p.product), p.size, Dates.format(Dates.unix2datetime(p.releaseTime),"dd-mm-yyyyTHH:MM:SS"), Dates.format(Dates.unix2datetime(p.dueTime),"dd-mm-yyyyTHH:MM:SS")] for p in productOrders])
	writeTablesToFile(filename, [miscTable, ordersTable])
end
