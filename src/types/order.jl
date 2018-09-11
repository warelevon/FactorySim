function decomposeOrder(orderList::Vector{ProductOrder},maxBatchSize::Int,factoryTask_dict::Dict{ProductType,Vector{FactoryTask}})
    batchList = Vector{Batch}()
    i=1
    for order in orderList
        while order.size> 0
            batch = Batch(i,factoryTask_dict[order.product],order.dueTime)
            batch.size = order.size>maxBatchSize ? maxBatchSize : order.size
            for j=1:length(batch.toDo)
                batch.toDo[j].batchIndex=i
            end
            order.size -= batch.size
            push!(batchList,batch)
            i += 1
        end
    end
    return batchList
end

function eddTaskOrder(batchlist::Vector{Batch})
    sortedList = sort(batchlist,by= x -> x.dueTime)
    schedule=Schedule()
    schedule2=Schedule()
    #return sortedList
    k=1
    for j = 1:length(sortedList[2].toDo)
        push!(schedule2.factoryTaskList,sortedList[2].toDo[j])
        schedule2.factoryTaskList[k].index=k
        k+=1
    end
    #return schedule2
    k=1
    for i = 1: length(sortedList)
        for j = 1:length(sortedList[i].toDo)
            push!(schedule.factoryTaskList,sortedList[i].toDo[j])
            schedule.factoryTaskList[k].index=k
            k+=1
        end
    end
    schedule.numTasks = length(schedule.factoryTaskList)
    return schedule
end
