using FactorySim
using JEMSS
using CSV
using DataFrames

# Change to a dictionary soon?!
path =  @__DIR__
str = joinpath(path, "ProductOrder.csv")

# Test out if csv file readds how it should. Debugging actually works?!
testArr = readOrderList(str);
Main.Juno.render(typeof(testArr))
