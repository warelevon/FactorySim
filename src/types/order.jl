function decomposeOrder(location::Location, orderList::Vector{ProductOrder},product_dict::Dict{ProductType,Vector{FactoryTask}})
    jobList = Vector{Job}()
    i=1
    for order in orderList
        while order.size> 0
            job = Job(i,product_dict[order.product],order.releaseTime,order.dueTime, location)
            for j=1:length(job.tasks)
                job.tasks[j].jobIndex=i
                job.tasks[j].parentIndex=(j==1 ? nullIndex : j-1)
                job.tasks[j].withinJobIndex = j
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
        for j = 1:length(sortedList[i].tasks)
            push!(schedule.factoryTaskList,sortedList[i].tasks[j])
            schedule.factoryTaskList[k].index=k
            k+=1
        end
    end
    schedule.numTasks = length(schedule.factoryTaskList)
    return schedule
end
