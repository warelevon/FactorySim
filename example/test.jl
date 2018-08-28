using FactorySim

factoryTask_dict = Dict{FactorySim.ProductType,Array{FactorySim.FactoryTask,1}}()
factoryTasks=[]
for i= 1:3
    push!(factoryTasks,FactoryTask())
    factoryTasks[i].machineType = workStation
end
factoryTasks[2].machineType = robot
factoryTask_dict[chair] = factoryTasks
factoryTasks=[]
for i= 1:4
    push!(factoryTasks,FactoryTask())
    factoryTasks[i].machineType = workStation
end
factoryTasks[3].machineType = robot
factoryTask_dict[table]=factoryTasks

orderlist = Vector{ProductOrder}()
order=ProductOrder()
order.size = 280
order.product=table
push!(orderlist,order)
order2=ProductOrder()
order2.size = 40
order2.product=chair
order2.dueTime= -1000
push!(orderlist,order2)

orderlist
factoryTask_dict

batchlist = decomposeOrder(orderlist,Int(50),factoryTask_dict)
for batch in batchlist
    print(batch.index,',',batch.size,',',length(batch.toDo),'\n')
end
value=eddTaskOrder(batchlist)
