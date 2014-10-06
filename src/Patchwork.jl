module Patchwork

using FunctionalCollections

import Base:
       convert,
       promote_rule,
       isequal,
       ==,
       >>,
       &,
       writemime

export Node,
       Elem,
       PCDATA,
       pcdata,
       NodeVector,
       Attrs,
       attrs,
       EmptyNode,
       MaybeKey,
       tohtml,
       writemime

typealias MaybeKey Union(Nothing, Symbol)

# A Patchwork node
abstract Node

key(n::Node) = n.key

immutable CDATA <: Node
    key::MaybeKey
    value::ByteString
end

immutable PCDATA <: Node
    key::MaybeKey
    value::ByteString
end
pcdata(xs...; _key::MaybeKey=nothing) =
    PCDATA(_key, string(xs...))

convert(::Type{Node}, s::String) = pcdata(s)
promote_rule(::Type{Node}, ::Type{String}) = Node

# Abstract out the word "Persistent"
typealias NodeVector   PersistentVector{Node}
typealias Attrs PersistentHashMap

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    PersistentVector{Node}(x)
convert(::Type{NodeVector}, x::NodeVector) =
    x
convert(::Type{NodeVector}, x::String) =
    PersistentVector{Node}([pcdata(x)])
convert(::Type{Attrs}, x) =
    Attrs(x)

# A DOM Element
immutable Elem{ns, tag} <: Node
    key::MaybeKey
    attributes::Attrs
    children::NodeVector
end

# A document type
immutable DocVariant{ns}
    elements::Vector{Symbol}
end

# constructors
Elem(ns, name, attrs, children, _key::MaybeKey=nothing) =
    Elem{is(ns, None) ? ns : symbol(ns) , symbol(name)}(
        _key, attrs, children)

Elem(ns, name, children=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
    Elem(ns, name, Attr[map(Attr, kwargs)...], children, _key=_key)

Elem(name, children=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
    Elem(None, name, Attr[map(Attr, kwargs)...], children, _key=_key)

isequal{ns,name}(a::Elem{ns,name}, b::Elem{ns,name}) =
    a === b || (isequal(a.attributes, b.attributes) &&
                sequal(a.children, b.children))
isequal(a::Elem, b::Elem) = false

==(a::PCDATA, b::PCDATA) = a.value == b.value
=={ns, name}(a::Parent{ns, name}, b::Parent{ns,name}) =
    a === b || (a.attributes == b.attributes &&
                a.children == b.children)
==(a::Elem, b::Elem) = false

# Combining elements
(>>)(a::Union(Node, String), b::Union(Node, String)) =
    NodeVector([convert(Node, a), convert(Node, b)])
(>>)(a::NodeVector, b::Union(Node, String)) =
    push(a, b)
(>>)(a::Union(Node, String), b::NodeVector) = # slow!
    append(NodeVector([a]), b)
(>>)(a::NodeVector, b::NodeVector) = append(a, b)

# Manipulating attributes
attrs(; kwargs...) = kwargs
(&){ns, name}(a::Elem{ns, name}, itr) =
    Elem{ns, name}(key(a), merge(a.attributes, itr), a.children)

include("html.jl")
include("combinators.jl")
include("writers.jl")
include("diff.jl")

end # module
