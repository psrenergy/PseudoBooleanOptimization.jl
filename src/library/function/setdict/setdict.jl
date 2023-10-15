const SetDict{V,T}    = Dict{Set{V},T}
const SetDictPBF{V,T} = PBF{V,T,SetDict{V,T}}

# Constructors
function PBF(Φ::S) where {V,T,S<:SetDict{V,T}}
    return PBF{V,T,S}(SetDict{V,T}(ω => c for (ω, c) in Φ if !iszero(c)))
end

function Base.zero(::Type{SetDictPBF{V,T}}) where {V,T}
    return SetDictPBF{V,T}(SetDict{V,T}())
end

function Base.one(::Type{SetDictPBF{V,T}}) where {V,T}
    return SetDictPBF{V,T}(SetDict{V,T}(Set{V}() => one(T)))
end

# Type promotion
function Base.promote_rule(
    ::Type{PBF{V,Tf,SetDict{V,Tf}}},
    ::Type{PBF{V,Tg,S}},
) where {V,Tf,Tg,S}
    T = promote_type(Tf, Tg)

    return SetDictPBF{V,T}
end

# Term parser
term(Φ::Type{SetDictPBF{V,T}}, v::V) where {V,T}                 = (term_head(Φ, v) => one(T))
term(Φ::Type{SetDictPBF{V,T}}, v::Nothing) where {V,T}           = (term_head(Φ, v) => one(T))
term(Φ::Type{SetDictPBF{V,T}}, v::Tuple{Vararg{V}}) where {V,T}  = (term_head(Φ, v) => one(T))
term(Φ::Type{SetDictPBF{V,T}}, v::AbstractVector{V}) where {V,T} = (term_head(Φ, v) => one(T))
term(Φ::Type{SetDictPBF{V,T}}, v::AbstractSet{V}) where {V,T}    = (term_head(Φ, v) => one(T))
term(Φ::Type{SetDictPBF{V,_}}, x::Any) where {V,_}               = (Set{V}() => term_tail(Φ, x))

function term(Φ::Type{SetDictPBF{V,T}}, (ω, c)::Pair{<:Any,<:Any}) where {V,T}
    c_ = term_tail(Φ, c)

    if iszero(c_)
        return (Set{V}() => zero(T))
    else
        ω_ = term_head(Φ, ω)

        return (ω_ => c_)
    end
end

term_head(::Type{SetDictPBF{V,_}}, ω::Set{V}) where {V,_}            = ω
term_head(::Type{SetDictPBF{V,_}}, ::Nothing) where {V,_}            = Set{V}()
term_head(::Type{SetDictPBF{V,_}}, ω::V) where {V,_}                 = Set{V}([ω])
term_head(::Type{SetDictPBF{V,_}}, ω::AbstractSet{V}) where {V,_}    = Set{V}(ω)
term_head(::Type{SetDictPBF{V,_}}, ω::AbstractVector{V}) where {V,_} = Set{V}(ω)
term_head(::Type{SetDictPBF{V,_}}, ω::NTuple{N,V}) where {N,V,_}     = Set{V}(ω)

term_tail(::Type{SetDictPBF{_,T}}, x::T) where {_,T} = x
term_tail(::Type{SetDictPBF{_,T}}, x) where {_,T}    = convert(T, x)

# Copy
function Base.copy!(f::SetDictPBF{V,T}, g::SetDictPBF{V,T}) where {V,T}
    sizehint!(f, length(g))

    copy!(f.Φ, g.Φ)

    return f
end

function Base.copy(f::F) where {V,T,F<:SetDictPBF{V,T}}
    return copy!(zero(F), f)
end

function Base.sizehint!(f::SetDictPBF{V,T}, n::Integer) where {V,T}
    sizehint!(f.Φ, n)

    return f
end

# Iterator & Length 
Base.length(f::SetDictPBF{V,T}) where {V,T}              = length(f.Φ)
Base.iterate(f::SetDictPBF{V,T}) where {V,T}             = iterate(f.Φ)
Base.iterate(f::SetDictPBF{V,T}, i::Integer) where {V,T} = iterate(f.Φ, i)

Base.collect(f::SetDictPBF{V,T}) where {V,T} = collect(f.Φ)

# Emptiness
Base.empty!(f::SetDictPBF{V,T}) where {V,T}  = empty!(f.Φ)
Base.isempty(f::SetDictPBF{V,T}) where {V,T} = isempty(f.Φ)

# Dictionary interface
Base.keys(f::SetDictPBF{V,T}) where {V,T}   = keys(f.Φ)
Base.values(f::SetDictPBF{V,T}) where {V,T} = values(f.Φ)

# Base.map!(φ::Function, f::SetDictPBF{V,T}) where {V,T} = map!(φ, values(f))

# Broadcast as scalar
Base.broadcastable(f::PBF{V,T,S}) where {V,T,S} = Ref(f)

# Indexing - in
function Base.haskey(f::F, ω) where {V,_,F<:SetDictPBF{V,_}}
    return haskey(f.Φ, term_head(F, ω))
end

function Base.haskey(f::F, ω...) where {V,_,F<:SetDictPBF{V,_}}
    return haskey(f, reduce(varmul, term_head.(F, ω)))
end

# Indexing - get
function Base.getindex(f::F, ω) where {V,T,F<:SetDictPBF{V,T}}
    return get(f.Φ, term_head(F, ω), zero(T))
end

function Base.getindex(f::F, ω...) where {V,T,F<:SetDictPBF{V,T}}
    return getindex(f, reduce(varmul, term_head.(F, ω)))
end

# Indexing - set
function Base.setindex!(f::F, c, ω) where {V,T,F<:SetDictPBF{V,T}}
    ω_ = term_head(F, ω)
    c_ = term_tail(F, c)

    if !iszero(c_)
        setindex!(f.Φ, c_, ω_)
    elseif haskey(f, ω_)
        delete!(f, ω_)
    end

    return c_
end

function Base.setindex!(f::F, c, ω...) where {V,T,F<:SetDictPBF{V,T}}
    return setindex!(f, c, reduce(varmul, term_head.(F, ω)))
end

function Base.delete!(f::F, ω) where {V,T,F<:SetDictPBF{V,T}}
    delete!(f.Φ, term_head(F, ω))

    return f
end

function Base.delete!(f::F, ω...) where {V,T,F<:SetDictPBF{V,T}}
    return delete!(f, reduce(varmul, term_head.(F, ω)))
end


function isconstant(f::SetDictPBF{V,T}) where {V,T}
    return isempty(f) || (length(f) == 1 && haskey(f, nothing))
end

function Base.iszero(f::SetDictPBF{V,T}) where {V,T}
    return isempty(f)
end

function Base.isone(f::SetDictPBF{V,T}) where {V,T}
    return isconstant(f) && isone(f[nothing])
end
