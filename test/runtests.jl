using BSON
using BSONMmap
using Test

dict = Dict(
    "str" => "abcdef",
    "nt" => (α = 1, β = 2, γ = "β"),
    "arr[uint8]" => zeros(UInt8, 7),
    "arr[str]" => ["α" "β"; "γ" "δ"],
    "arr[nt]" => repeat([(a = 1, b = "α", c = 1f0)], 2),
    "group" => Dict(
        "arr[float32]" => zeros(Float32, 10),
        "group" => Dict("arr[float64]" => ones(10)),
        )
    )
h5save("test.h5", dict)
@test bsload("test.h5", mmaparrays = true) == dict
@test bsload("test.h5", mmaparrays = false) == dict

mutable struct Data
    x::Array{Float32, 2}
    y::Array{Float64, 3}
    z::Dict{String, Int}
    w::String
end
data = Data(rand(Float32, 2, 2), rand(2, 2, 2), Dict("a" => 1), "abcd")
bssave("test.bson", data, force = true)
for mmap in (true, false)
    data′ = bsload("test.h5", Data, mmaparrays = mmap)
    for s in fieldnames(Data)
        @test getfield(data, s) == getfield(data′, s)
    end
end

rm("test.h5")
