type FactoryTask

    index::Integer
    batchIndex::Integer
    machineType::MachineType

    withWorker::Float
    withoutWorker::Float
    isComplete::Bool

    FactoryTask() = new(nullIndex,nullIndex,nullMachineType,nullTime,nullTime,false)
end

type Batch
    index::Integer
    size::Integer

    toDo::Vector{FactoryTask}
    completed::Vector{FactoryTask}
    dueTime::Float

    Batch() = new(nullIndex,nullIndex,[],[],nullTime)
    Batch(index::Integer,toDo::Vector{FactoryTask},dueTime::Float) = new(index,nullIndex,deepcopy(toDo),[],dueTime)

end

type Schedule

    index::Integer
    numfactoryTasks::Integer

    factoryTaskList::Vector{FactoryTask}

    Schedule() = new(nullIndex,0,Vector{FactoryTask}())
end

type ProductOrder
    product::ProductType
    size::Integer
    dueTime::Float

    ProductOrder() = new(nullProductType,nullIndex,nullTime)
    ProductOrder(product::ProductType, size::Integer, dueTime::Float) = new(product,size,dueTime)
end
