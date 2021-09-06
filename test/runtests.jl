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
        "arr[float32]" => zeros(Float32, 11),
        "group" => Dict("arr[float64]" => ones(10)),
        )
    )
bssave("dict.bson", dict)
@test bsload("dict.bson", mmaparrays = false) == dict
@test bsload("dict.bson", mmaparrays = true) == dict

mutable struct Data{TX, TY}
    x::TX
    y::TY
    z::Dict{String, Int}
    w::String
end
data = Data(rand(Float32, 7, 3), rand(2, 2, 2), Dict("a" => 1), "abcd")
bssave("data.bson", data, force = true)
for mmap in (true, false)
    data′ = bsload("data.bson", Data, mmaparrays = mmap)
    for s in fieldnames(Data)
        @test getfield(data, s) == getfield(data′, s)
    end
end

if !Sys.iswindows()
    rm("data.bson", force = true)
    rm("dict.bson", force = true)
end