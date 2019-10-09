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
bssave("test.bson", dict)
@test bsload("test.bson", mmaparrays = true) == dict
@test bsload("test.bson", mmaparrays = true) == dict

mutable struct Data{TX, TY}
    x::TX
    y::TY
    z::Dict{String, Int}
    w::String
end
data = Data(rand(Float32, 7, 3), rand(2, 2, 2), Dict("a" => 1), "abcd")
bssave("test.bson", data, force = true)
for mmap in (true, false)
    data′ = bsload("test.bson", Data, mmaparrays = mmap)
    for s in fieldnames(Data)
        @test getfield(data, s) == getfield(data′, s)
    end
end

rm("test.bson", force = true)
