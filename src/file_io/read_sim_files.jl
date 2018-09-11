# Function to read read the order list and save info to the correct types
function readOrderList(str::String)
    myDF = readDlmFile(str)

    # Create data from calls table
    myArray = convert(Array, myDF[:,1:4])
    Main.Juno.render(myArray)
    myArray
end
