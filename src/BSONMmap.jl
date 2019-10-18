module BSONMmap

using Mmap, Requires, BSON
using BSON: reinterpret_, BSONType, null, document, array, binary, jtype
using BSON: parse_doc, parse_array, bson_type, bson_pair

export bsload, bssave

BSON.reinterpret_(::Type{T}, x) where T = T[_x for _x in reinterpret(T, x)]

global cache = Set()
function bytes2array(bytes, T, dims...)
    push!(cache, bytes)
    ptr = convert(Ptr{T}, pointer(bytes))
    arr = unsafe_wrap(Array, ptr, dims)
    finalizer(arr) do z
        delete!(cache, bytes)
    end
    return arr
end

@init BSON.tags[:array] = d -> begin
    isbitstype(d[:type]) ?
    sizeof(d[:type]) == 0 ?
        fill(d[:type](), d[:size]...) :
        get(ENV, "BSON_MMAP", "false") == "false" ?
            reshape(reinterpret_(d[:type], d[:data]), d[:size]...) :
            bytes2array(d[:data], d[:type], d[:size]...) :
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
            @assert position(io) % 8 == 0
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

BSON.parse_cstr(io::IO) = strip(readuntil(io, '\0'))

function BSON.bson_doc(io::IO, doc)
    pi = position(io)
    write(io, zero(Int32))
    for (k, v) in doc
        bson_pair(io, k, v)
    end
    write(io, BSON.eof)
    pf = position(io)
    seek(io, pi)
    write(io, Int32(pf - pi))
    seek(io, pf)
    return
end

function BSON.bson_pair(io::IO, k, v::Vector{UInt8})
    write(io, bson_type(v))
    k = Base.string(k)
    n = (position(io) + length(k) + 6) % 8
    if n != 0
        k = rpad(k, length(k) + 8 - n)
    end
    write(io, k, 0x00)
    write(io, Int32(length(v)), 0x00)
    @assert position(io) % 8 == 0
    write(io, v)
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

bssave(dst, dict::AbstractDict) = withenv(() -> BSON.bson(dst, dict))

end # module
