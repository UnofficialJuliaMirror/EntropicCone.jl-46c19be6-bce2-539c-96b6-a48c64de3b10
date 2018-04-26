export EntropyVector
export PrimalEntropy, cardminusentropy, cardentropy, invalidfentropy, matusrentropy, entropyfrompdf, subpdf, toTikz
export DualEntropy, DualEntropyLift, nonnegative, nondecreasing, submodular, submodulareq, ingleton
import Base.isless

# Entropy Vector

function ntodim(n::Int)
    # It will works with bitsets which are unsigned
    fullset(n)
end
function ntodim(n::Vector{Int})
    map(ntodim, n)
end

function indset(n::Int)
    setsto(ntodim(n))
end

function dimton(N)
    n = Int(round(log2(N + 1)))
    if ntodim(n) != N
        error("Illegal size of entropic constraint")
    end
    n
end

abstract type EntropyVector{N, T<:Real} end # <: AbstractVector{T} end

function indset(h::EntropyVector, id::Int)
    indset(h.n[id])
end

#Store vectors as tuple to reuse their `isless'
function Base.isless(h::EntropyVector{N}, g::EntropyVector{N}) where N
    for i in 1:length(h.h)
        if h.h[i] < g.h[i]
            return true
        elseif h.h[i] > g.h[i]
            return false
        end
    end
    return false
end

Base.size(h::EntropyVector{N}) where {N} = (N,)
Base.IndexStyle(::Type{EntropyVector}) = Base.LinearFast()
#Base.getindex(h::EntropyVector, i::Int) = h.h[i]
#Base.getindex{T}(h::EntropyVector, i::AbstractArray{T,1}) = EntropyVector(h.h[i])
Base.getindex(h::EntropyVector, i) = h.h[i]
Base.setindex!(h::EntropyVector{N, T}, v::T, i::Integer) where {N, T} = h.h[i] = v

#function *(x, h::EntropyVector)
#  EntropyVector(x * h.h)
#end

#function entropyof(p::AbstractArray{Real, n})
#  println(n)
#  for i in indset(n)
#  end
#end

abstract type AbstractDualEntropy{L, N, T<:Real} <: EntropyVector{N, T} end

mutable struct DualEntropy{L, N, T<:Real, AT<:AbstractVector{T}} <: AbstractDualEntropy{L, N, T}
    n::Int
    h::AT
    liftid::Int

    function DualEntropy{L, N, T}(n::Int, h::AbstractVector{T}, liftid::Int=1) where {L, N, T}
        if N != length(h)
            error("Dimension N should be equal to the length of h")
        end
        if ntodim(n) != N
            error("Number of variables and dimension does not match")
        end
        if liftid < 1
            error("liftid must be positive")
        end
        new{L, N, T, typeof(h)}(n, h, liftid)
    end

end

DualEntropy{L, N, T}(n::Int, liftid::Int=1) where {L, N, T} = DualEntropy{L, N, T}(n, Vector{T}(N), liftid)
DualEntropy{L, N}(n::Int, h::AbstractVector{T}, liftid::Int=1) where {L, N, T} = DualEntropy{L, N, T}(n, h, liftid)
DualEntropy{L, N}(h::AbstractVector, liftid::Int=1) where {L, N} = DualEntropy{L, N}(dimton(N), h, liftid)
DualEntropy{L}(h::AbstractVector{T}, liftid::Int=1) where {L, T} = DualEntropy{L, length(h)}(h, liftid)

function setequality(h::DualEntropy, L::Bool)
    DualEntropy{L}(h.n, h.h, h.liftid)
end

#Base.convert{N, T}(::Type{HRepresentation{T}}, h::DualEntropy{N, T}) = Base.convert(HRepresentation{T}, [h])
#Doesn't work

# L <-> linearity/equality
mutable struct DualEntropyLift{L, N, T<:Real} <: AbstractDualEntropy{L, N, T}
    n::Vector{Int}
    h::AbstractVector{T}

    function DualEntropyLift{L, N, T}(n::Vector{Int}, h::AbstractVector{T}=spzeros(T, N)) where {L, N, T}
        if sum(ntodim(n)) != N
            error("Number of variables and dimension does not match")
        end
        if N != length(h)
            error("Dimension N should be equal to the length of h")
        end
        new{L, N, T}(n, h)
    end
end

function DualEntropyLift(h::DualEntropy{L, N, T}, m) where {L, N, T}
    hlift = spzeros(T, m*N)
    offset = (h.liftid-1)*N
    hlift[(offset+1):(offset+N)] = h.h
    DualEntropyLift{L, m*N, T}(h.n*ones(Int, m), hlift)
end

DualEntropyLift{L}(n::Vector{Int}, h::AbstractVector{T}) where {L, T} = DualEntropyLift{L, length(h), T}(n, h)

Polyhedra.HRepElement(h::Union{DualEntropy{true, N, T}, DualEntropyLift{true, N, T}}) where {N, T}  = HyperPlane(h.h, zero(T))
Polyhedra.HRepElement(h::Union{DualEntropy{false, N, T}, DualEntropyLift{false, N, T}}) where {N, T} = HalfSpace(h.h, zero(T))
Polyhedra.hrep(hs::Vector{<:DualEntropy}) = hrep(HRepElement.(hs))
Polyhedra.hrep(hs::DualEntropy) = hrep([hs])
#function Base.convert(::Type{HyperPlane{N, T, AT}}, h::DualEntropy{true, N}) where {N, T, AT}
#    HyperPlane{N, T, AT}(h.h, zero(T))
#end
#function Base.convert(::Type{HalfSpace{N, T, AT}}, h::DualEntropy{false, N}) where {N, T, AT}
#    HalfSpace{N, T, AT}(-h.h, zero(T))
#end

#function Polyhedra.hrep(hs::Vector{DualEntropy{false, N, T, AT}}) where {N, T, AT}
#    hrep(HalfSpace{N, T, AT}.(hs))
#end

abstract type AbstractPrimalEntropy{N, T<:Real} <: EntropyVector{N, T} end

mutable struct PrimalEntropy{N, T<:Real} <: AbstractPrimalEntropy{N, T}
    n::Int
    h::AbstractVector{T}
    liftid::Int # 1 by default: the first cone of the lift

    function PrimalEntropy{N, T}(n::Int, h::AbstractVector{T}, liftid::Int=1) where {N, T}
        if N != length(h)
            error("Dimension N should be equal to the length of h")
        end
        if ntodim(n) != N
            error("Number of variables and dimension does not match")
        end
        new{N, T}(n, h, liftid)
    end
end

PrimalEntropy{N, T}(n::Int, liftid::Int=1) where {N, T} = PrimalEntropy{N, T}(n, Vector{T}(N), liftid)
PrimalEntropy{N}(n::Int, h::AbstractVector{T}, liftid::Int=1) where {N, T} = PrimalEntropy{N, T}(n, h, liftid)
PrimalEntropy{N}(h::AbstractVector, liftid::Int=1) where N = PrimalEntropy{N}(dimton(N), h, liftid)
PrimalEntropy(h::AbstractVector, liftid::Int=1) = PrimalEntropy{length(h)}(h, liftid)

mutable struct PrimalEntropyLift{N, T<:Real} <: AbstractPrimalEntropy{N, T}
    n::Array{Int,1}
    h::AbstractVector{T}
    liftid::Array{Int,1}

    #function PrimalEntropyLift(n::Array{Int,1}, liftid::Array{Int,1})
    #  new(n, sum(ntodim(n)), liftid)
    #end

    function PrimalEntropyLift{N, T}(n::Array{Int,1}, h::AbstractVector{T}, liftid::Array{Int,1}) where {N, T}
        if sum(ntodim(n)) != N
            error("Number of variables and dimension does not match")
        end
        new{N, T}(n, h, liftid)
    end

end

PrimalEntropyLift(n::Array{Int,1}, h::AbstractVector{T}, liftid::Array{Int,1}) where {T<:Real} = PrimalEntropyLift{Int(sum(ntodim(n))), T}(n, h, liftid)

function Base.:(*)(h1::AbstractPrimalEntropy{N1, T}, h2::AbstractPrimalEntropy{N2, T}) where {N1, N2, T<:Real}
    if length(h1.liftid) + length(h2.liftid) != length(union(IntSet(h1.liftid), IntSet(h2.liftid)))
        error("liftids must differ")
    end
    PrimalEntropyLift([h1.n; h2.n], [h1.h; h2.h], [h1.liftid; h2.liftid])
end

Base.convert(::Type{PrimalEntropy{N, T}}, h::PrimalEntropy{N, S}) where {N, T<:Real,S<:Real} = PrimalEntropy(Array{T}(h.h))

function subpdf(p::Array{Float64,n}, S::EntropyIndex) where n
    cpy = copy(p)
    for j = 1:n
        if !myin(j, S)
            cpy = reducedim(+, cpy, j, 0.)
        end
    end
    cpy
end

subpdf(p::Array{Float64,n}, s::Signed) where {n} = subpdf(p, set(s))

function entropyfrompdf(p::Array{Float64,n}) where n
    h = PrimalEntropy{Int(ntodim(n)), Float64}(n, 1)
    for i = indset(n)
        h[i] = -sum(map(xlogx, subpdf(p, i)))
    end
    h
end

Base.dot(hd::DualEntropy, hp::PrimalEntropy) = dot(hp, hd)
function Base.dot(hp::PrimalEntropy{N}, hd::DualEntropy{L, N}) where {L, N}
    @assert hp.liftid == hd.liftid
    dot(hp.h, hd.h)
end
Base.:(-)(h::PrimalEntropy{N, T}) where {N, T<:Real}      = PrimalEntropy{N, T}(-h.h, h.liftid)
Base.:(-)(h::DualEntropy{L, N, T}) where {L, N, T<:Real}  =   DualEntropy{L, N, T}(-h.h, h.liftid)
Base.:(-)(h::PrimalEntropyLift{N, T}) where {N, T<:Real}  = PrimalEntropyLift{N, T}(h.n, -h.h, h.liftid)
Base.:(-)(h::DualEntropyLift{L, N, T}) where {L, N, T<:Real} =   DualEntropyLift{L, N, T}(h.n, -h.h)
Base.:(*)(h::DualEntropy{true, N}, α::Number) where N  = DualEntropy{true, N}(h.n, h.h*α, h.liftid)
Base.:(*)(α::Number, h::DualEntropy{true, N}) where N  = DualEntropy{true, N}(h.n, α*h.h, h.liftid)
Base.:(*)(h::DualEntropy{false, N}, α::Number) where N = (@assert α >= 0; DualEntropy{false, N}(h.n, h.h*α, h.liftid))
Base.:(*)(α::Number, h::DualEntropy{false, N}) where N = (@assert α >= 0; DualEntropy{false, N}(h.n, α*h.h, h.liftid))
Base.:(*)(h::PrimalEntropy{N}, α::Number) where N = PrimalEntropy{N}(h.n, h.h*α, h.liftid)
Base.:(*)(α::Number, h::PrimalEntropy{N}) where N = PrimalEntropy{N}(h.n, h.h*α, h.liftid)
Base.:(==)(h1::PrimalEntropy{N}, h2::PrimalEntropy{N}) where N = h1.liftid == h2.liftid && h1.h == h2.h
Base.:(==)(h1::DualEntropy{N}, h2::DualEntropy{N}) where N = h1.liftid == h2.liftid && h1.h == h2.h
function Base.:(+)(h1::PrimalEntropy{N}, h2::PrimalEntropy{N}) where N
    @assert h1.liftid == h2.liftid
    PrimalEntropy{N}(h1.h + h2.h, h1.liftid)
end
function Base.:(+)(h1::DualEntropy{L, N}, h2::DualEntropy{L, N}) where {L, N}
    @assert h1.liftid == h2.liftid
    DualEntropy{L, N}(h1.h + h2.h, h1.liftid)
end
function Base.:(+)(h1::PrimalEntropyLift{N}, h2::PrimalEntropyLift{N}) where N
    @assert h1.n == h2.n
    PrimalEntropyLift{N}(h1.h + h2.h, h1.liftid)
end
function Base.:(+)(h1::DualEntropyLift{L, N}, h2::DualEntropyLift{L, N}) where {L, N}
    @assert h1.n == h2.n
    DualEntropyLift{L, N}(h1.h + h2.h, h1.liftid)
end
function Base.:(-)(h1::PrimalEntropy{N}, h2::PrimalEntropy{N}) where N
    @assert h1.liftid == h2.liftid
    PrimalEntropy{N}(h1.h - h2.h, h1.liftid)
end
function Base.:(-)(h1::DualEntropy{L, N}, h2::DualEntropy{L, N}) where {L, N}
    @assert h1.liftid == h2.liftid
    DualEntropy{L, N}(h1.h - h2.h, h1.liftid)
end
function Base.:(-)(h1::PrimalEntropyLift{N}, h2::PrimalEntropyLift{N}) where N
    @assert h1.n == h2.n
    PrimalEntropyLift{N}(h1.h - h2.h, h1.liftid)
end
function Base.:(-)(h1::DualEntropyLift{L, N}, h2::DualEntropyLift{L, N}) where {L, N}
    @assert h1.n == h2.n
    DualEntropyLift{L, N}(h1.h - h2.h, h1.liftid)
end

function constprimalentropy(n, x::T) where T<:Real
    PrimalEntropy(x * ones(T, ntodim(n)))
end
function constdualentropy(n, x::T) where T<:Real
    if x == 0
        DualEntropy{false}(spzeros(T, ntodim(n)))
    else
        DualEntropy{false}(x * ones(T, ntodim(n)))
    end
end

function Base.one(h::PrimalEntropy{N,T}) where {N,T<:Real}
    constprimalentropy(h.n, one(T))
end
function Base.one(h::DualEntropy{L,N,T}) where {L, N, T}
    constdualentropy(h.n, one(T))
end

#Base.similar(h::EntropyVector) = EntropyVector(h.n)
# Used by e.g. hcat
Base.similar(h::PrimalEntropy, ::Type{T}, dims::Dims) where {T} = length(dims) == 1 ? PrimalEntropy{dims[1], T}(dimton(dims[1]), h.liftid) : Array{T}(dims...)
Base.similar(h::DualEntropy, ::Type{T}, dims::Dims) where {T} = length(dims) == 1 ? DualEntropy{dims[1], T}(dimton(dims[1]), h.equality, h.liftid) : Array{T}(dims...)
# Cheating here, I cannot deduce n just from dims so I use copy(h.n)
Base.similar(h::PrimalEntropyLift, ::Type{T}, dims::Dims) where {T} = length(dims) == 1 ? PrimalEntropyLift{dims[1], T}(copy(h.n), h.liftid) : Array{T}(dims...)
Base.similar(h::DualEntropyLift, ::Type{T}, dims::Dims) where {T} = length(dims) == 1 ? DualEntropyLift{dims[1], T}(copy(h.n), h.equality) : Array{T}(dims...)
#Base.similar{T}(h::EntropyVector, ::Type{T}) = EntropyVector(h.n)

# Classical Entropy Inequalities
function dualentropywith(n, pos, neg)
    ret = constdualentropy(n, 0)
    # I use -= and += in case some I is in pos and neg
    for I in pos
        if I != emptyset()
            ret[I] += 1
        end
    end
    for I in neg
        if I != emptyset()
            ret[I] -= 1
        end
    end
    ret
end

function nonnegative(n, S::EntropyIndex)
    dualentropywith(n, [S], [])
end
function nonnegative(n, s::Signed)
    nonnegative(n, set(s))
end

function nondecreasing(n, S::EntropyIndex, T::EntropyIndex)
    T = union(S, T)
    x = dualentropywith(n, [T], [S]) # fix of weird julia bug
    print("")
    x
end
function nondecreasing(n, s::Signed, t::Signed)
    nondecreasing(n, set(s), set(t))
end

function submodular(n, S::EntropyIndex, T::EntropyIndex, I::EntropyIndex)
    S = union(S, I)
    T = union(T, I)
    U = union(S, T)
    h = dualentropywith(n, [S, T], [U, I])
    h
end
submodular(n, S::EntropyIndex, T::EntropyIndex) = submodular(n, S, T, S ∩ T)
submodular(n, s::Signed, t::Signed, i::Signed) = submodular(n, set(s), set(t), set(i))
submodular(n, s::Signed, t::Signed) = submodular(n, set(s), set(t))

function submodulareq(n, S::EntropyIndex, T::EntropyIndex, I::EntropyIndex)
    h = submodular(n, S, T, I)
    h.equality = true
    h
end
submodulareq(n, S::EntropyIndex, T::EntropyIndex) = submodulareq(n, S, T, S ∩ T)
submodulareq(n, s::Signed, t::Signed, i::Signed) = submodulareq(n, set(s), set(t), set(i))
submodulareq(n, s::Signed, t::Signed) = submodulareq(n, set(s), set(t))

function ingleton(n, i, j, k, l)
    pos = []
    I = singleton(i)
    J = singleton(j)
    K = singleton(k)
    L = singleton(l)
    ij = union(I, J)
    kl = union(K, L)
    ijkl = union(ij, kl)
    for s in indset(n)
        if issubset(s, ijkl) && card(s) == 2 && s != ij
            pos = [pos; s]
        end
    end
    ikl = union(I, kl)
    jkl = union(J, kl)
    dualentropywith(n, pos, [ij, K, L, ikl, jkl])
end

function getkl(i, j)
    x = 1:4
    kl = x[(x.!=i) & (x.!=j)]
    (kl[1], kl[2])
end

function ingleton(i, j)
    ingleton(4, i, j, getkl(i, j)...)
end

# Classical Entropy Vectors
function cardminusentropy(n, I::EntropyIndex)
    h = constprimalentropy(n, 0)
    for J in indset(n)
        h[J] = card(setdiff(J, I))
    end
    return h
end
cardminusentropy(n, i::Signed) = cardminusentropy(n, set(i))

function cardentropy(n)
    return cardminusentropy(n, emptyset())
end

#min(h1, h2) gives Array{Any,1} instead of EntropyVector :(
function _min(h1::PrimalEntropy{N, T}, h2::PrimalEntropy{N, T}) where {N, T<:Real} # FIXME cannot make it work with min :(
    PrimalEntropy{N}(min.(h1.h, h2.h))
end

function invalidfentropy(S::EntropyIndex)
    n = 4
    #ret = min(constentropy(n, 4), 2 * cardentropy(n)) #can't make it work
    h = _min(constprimalentropy(n, 4), cardentropy(n) * 2)
    for i in indset(n)
        if i != S && card(i) == 2
            h[i] = 3
        end
    end
    return h
end

function invalidfentropy(s::Signed)
    return invalidfentropy(set(s))
end

function matusrentropy(t, S::EntropyIndex)
    n = 4
    h = _min(constprimalentropy(n, t), cardminusentropy(n, S))
    return h
end

function matusrentropy(t, s::Signed)
    return matusrentropy(t, set(s))
end

# Manipulation

function toTikz(h::EntropyVector)
    dens = [el.den for el in h.h]
    hlcm = reduce(lcm, 1, dens)
    x = h.h * hlcm
    println(join(Vector{Int}(x), " "))
end

function toTikz(h::EntropyVector{Rational{T}}) where T
    x = Vector{Real}(h.h)
    i = h.h .== round(h.h)
    x[i] = Vector{Int}(h.h[i])
    println(join(x, " "))
end

function Base.show(io::IO, h::EntropyVector)
    offset = 0
    for i in eachindex(collect(h.n))
        for l in h.n[i]:-1:1
            for j in indset(h, i)
                if card(j) == l
                    bitmap = bits(j)[end-h.n[i]+1:end]
                    val = h.h[offset+j]
                    if val == 0
                        print(io, " $(bitmap):$(val)")
                    else
                        print_with_color(:blue, io, " $(bitmap):$(val)")
                    end
                end
            end
            if i != length(h.n) || l != 1
                println(io)
            end
        end
        offset += ntodim(h.n[i])
    end
end
