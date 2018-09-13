function decomposeOrder(orderList::Vector{ProductOrder},factoryTask_dict::Dict{ProductType,Vector{FactoryTask}})
    jobList = Vector{Job}()
    i=1
    for order in orderList
        while order.size> 0
            job = Job(i,factoryTask_dict[order.product],order.dueTime)
            for j=1:length(job.toDo)
                job.toDo[j].jobIndex=i
            end
            order.size -= 1
            push!(jobList,job)
            i += 1
        end
    end
    return jobList
end

function eddTaskOrder(joblist::Vector{Job})
    sortedList = sort(joblist,by= x -> x.dueTime)
    schedule=Schedule()
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
