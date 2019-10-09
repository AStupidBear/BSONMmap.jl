module BSONMmap

using Mmap, Requires, BSON
using BSON: reinterpret_, BSONType, null, document, array, binary, jtype, parse_doc, parse_array

export bsload, bssave

BSON.reinterpret_(::Type{T}, x) where T = T[_x for _x in reinterpret(T, x)]

@init BSON.tags[:array] = d -> begin
  r = get(ENV, "BSON_MMAP", "false") == "true" ? reinterpret : reinterpret_
  isbitstype(d[:type]) ?
    sizeof(d[:type]) == 0 ?
      fill(d[:type](), d[:size]...) :
      reshape(r(d[:type], d[:data]), d[:size]...) :
    Array{d[:type]}(reshape(d[:data], d[:size]...))
end

function BSON.parse_tag(io::IO, tag::BSONType)
    if tag == null
        nothing
    elseif tag == document
        parse_doc(io)
    elseif tag == array
        parse_array(io)
    elseif tag == BSON.string
        len = read(io, Int32) - 1
        s = String(read(io, len))
        eof = read(io, 1)
        s
    elseif tag == binary
        len = read(io, Int32)
        subtype = read(io, 1)
        if get(ENV, "BSON_MMAP", "false") == "true"
            arr = Mmap.mmap(io, Vector{UInt8}, len)
            skip(io, len)
            arr
        else
            read(io, len)
        end
    else
        read(io, jtype(tag))
    end
end

function bsload(src, ::Type{T}; mmaparrays = false) where T
    dict = bsload(src, mmaparrays = mmaparrays)
    o = Any[]
    for s in fieldnames(T)
        if s == :src
            x = src
        else
            ft = fieldtype(T, s)
            x = s ∈ keys(dict) || !(ft <: AbstractArray) ? dict[s] :
                zeros(ft.parameters[1], ntuple(i -> 0, ft.parameters[2]))
        end
        push!(o, x)
    end
    return T(o...)
end

bsload(src; mmaparrays = true) = withenv(() -> BSON.load(src), "BSON_MMAP" => mmaparrays)

todict(x) = Dict{Symbol, Any}(s => getfield(x, s) for s in fieldnames(typeof(x)))

function bssave(dst, obj; force = false)
    isfile(dst) && rm(dst)
    isempty(dst) && error("dst is empty")
    if isdefined(obj, :src) && isfile(obj.src) &&
        splitext(dst)[2] == splitext(obj.src)[2] &&
        !Sys.iswindows() && !force
        symlink(obj.src, dst)
    else
        bssave(dst, delete!(todict(obj), :src))
    end
    return dst
end

bssave(dst, dict::AbstractDict) = withenv(() -> BSON.bson(dst, dict), "BSON_ALIGNMENT" => align(dict))

align(d::AbstractDict) = lcm(Int[align(x) for x in values(d)])

align(x::AbstractArray{T}) where T = isbitstype(T) ? sizeof(T) : 1

align(obj) = lcm(Int[align(x) for x in fieldvalues(obj)])

fieldvalues(obj::T) where T = [getfield(obj, s) for s in fieldnames(T)]

end # module
