using FactorySim
using JEMSS
using CSV
using DataFrames

# Change to a dictionary soon?!
str = joinpath(@__DIR__, "orderList.csv")

# Function to test
function inOutTest(str)
    myDF = CSV.read(str)
    myArray = convert(Array, myDF[:,1:4])
    Main.Juno.render(myArray)
    myArray
end

# Test out if csv file readds how it should. Debugging actually works?!
@enter inOutTest(str)
