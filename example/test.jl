using FactorySim

factoryTask_dict = Dict{FactorySim.ProductType,Array{FactorySim.FactoryTask,1}}()
factoryTasks=[]
for i= 1:3
    push!(factoryTasks,FactoryTask())
    factoryTasks[i].machineType = workbench
end
factoryTasks[2].machineType = robot
factoryTask_dict[chair] = factoryTasks
factoryTasks=[]
for i= 1:4
    push!(factoryTasks,FactoryTask())
    factoryTasks[i].machineType = workbench
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

joblist = decomposeOrder(orderlist,Int(50),factoryTask_dict)
value=eddTaskOrder(joblist)
typeof(joblist[1].tasks[1])
