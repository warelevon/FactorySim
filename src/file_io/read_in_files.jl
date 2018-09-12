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
