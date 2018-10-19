function decomposeOrder(arrivalLocation::Location, orderList::Vector{ProductOrder},product_dict::Dict{ProductType,Vector{FactoryTask}})
    ## Author: Levon ##
    # this function decomposes an order into various jobs containing their required tasks
    jobList = Vector{Job}()
    i=1
    for order in orderList
        while order.size> 0
            job = Job(i,product_dict[order.product],order.releaseTime,order.dueTime, arrivalLocation)
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
    ## Author: Levon ##
    # this function breaks down a list of jobs into
    # a list of incomplete tasks sorted by earliest due date
    sortedList = sort(joblist,by= x -> x.dueTime)
    taskList=Vector{FactoryTask}()
    k=1
    for i = 1: length(sortedList)
        for j = 1:length(sortedList[i].tasks)
            task = sortedList[i].tasks[j]
            if !task.isComplete
                push!(taskList,task)
                taskList[k].index=k
                k+=1
            end
        end
    end
    return taskList
end


function erdTaskOrder(joblist::Vector{Job})
    ## Author: Levon ##
    # this function breaks down a list of jobs into
    # a list of incomplete tasks sorted by earliest release date
    sortedList = sort(joblist,by= x -> x.releaseTime)
    taskList=Vector{FactoryTask}()
    k=1
    for i = 1: length(sortedList)
        for j = 1:length(sortedList[i].tasks)
            task = sortedList[i].tasks[j]
            if !task.isComplete
                push!(taskList,task)
                taskList[k].index=k
                k+=1
            end
        end
    end
    return taskList
end
