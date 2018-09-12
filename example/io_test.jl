using FactorySim
using JEMSS

# Change to a dictionary soon?!
path =  @__DIR__
productOrderName = joinpath(path, "ProductOrder.csv")

# Test out if csv file readds how it should. Debugging actually works?!
testOrderList = readOrderList(productOrderName);
Main.Juno.render(testOrderList)
