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

export Attr,
       Node,
       Elem,
       PCDATA,
       pcdata,
       NodeVector,
       Attrs,
       attrs,
       EmptyNode,
       MaybeKey,
       Parent,
       Leaf,
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

# An attribute
immutable Attr{ns, name}
    value
end

# Abstract out the word "Persistent"
typealias NodeVector   PersistentVector{Node}
typealias Attrs PersistentSet{Attr}

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    PersistentVector{Node}(x)
convert(::Type{NodeVector}, x::NodeVector) =
    x
convert(::Type{NodeVector}, x::String) =
    PersistentVector{Node}([pcdata(x)])
convert(::Type{Attrs}, x) =
    Attrs(x)

# An XML/HTML element
abstract Elem{ns, name} <: Node

# HTML5 requires a distinction between parent and leaf nodes.
immutable Parent{ns, name} <: Elem{ns, name}
    key::MaybeKey
    attributes::Attrs
    children::NodeVector
end

immutable Leaf{ns, name} <: Elem{ns, name}
    key::MaybeKey
    attributes::Attrs
end

# constructors
Attr(ns, name, val) = Attr{symbol(ns), symbol(name)}(val)
Attr(x::(Any, Any)) = Attr{None, symbol(x[1])}(x[2])

Parent(ns, name, attrs, children, _key::MaybeKey=nothing) =
    Parent{is(ns, None) ? ns : symbol(ns) , symbol(name)}(
        _key, attrs, children)

Parent(ns, name, children=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
    Parent(ns, name, Attr[map(Attr, kwargs)...], children, _key=_key)

Parent(name, children=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
    Parent(None, name, Attr[map(Attr, kwargs)...], children, _key=_key)

Leaf(ns, name, attrs, _key::MaybeKey=nothing) =
    Leaf{is(ns, None) ? ns : symbol(ns) , symbol(name)}(
        _key, attrs)
Leaf(ns, name; _key::MaybeKey=nothing, kwargs...) =
    Leaf{symbol(ns), symbol(name)}(
        Attr[map(Attr, kwargs)...], _key=_key)
Leaf(name; _key::MaybeKey=nothing, kwargs...) =
    Leaf{nothing, symbol(name)}(
        Attr[map(Attr, kwargs)...], _key=nothing)

isequal{ns,name}(a::Parent{ns,name}, b::Parent{ns,name}) =
    a === b || (isequal(a.attributes, b.attributes) &&
                sequal(a.children, b.children))
isequal(a::Parent, b::Parent) = false

==(a::PCDATA, b::PCDATA) = a.value == b.value
=={ns, name}(a::Parent{ns, name}, b::Parent{ns,name}) =
    a === b || (a.attributes == b.attributes &&
                a.children == b.children)
==(a::Parent, b::Parent) = false

isequal{ns, name}(a::Leaf{ns, name}, b::Leaf{ns, name}) =
    a === b || isequal(a.attributes, b.attributes)
isequal(a::Leaf, b::Leaf) = false
=={ns, name}(a::Leaf{ns, name}, b::Leaf{ns, name}) =
    a === b || a.attributes == b.attributes
==(a::Leaf, b::Leaf) = false

# Combining elements 
(>>)(a::Union(Node, String), b::Union(Node, String)) =
    NodeVector([convert(Node, a), convert(Node, b)])
(>>)(a::NodeVector, b::Union(Node, String)) =
    push(a, b)
(>>)(a::Union(Node, String), b::NodeVector) = # slow!
    append(NodeVector([a]), b)
(>>)(a::NodeVector, b::NodeVector) = append(a, b)

# Manipulating attributes
attrs(; kwargs...) = Attrs(map(Attr, kwargs))
(&){ns, name}(a::Parent{ns, name}, b::Union(Attr, Attrs)) =
    Parent{ns, name}(key(a), union(a.attributes, b), a.children)
(&){ns, name}(a::Leaf{ns, name}, b::Union(Attr, Attrs)) =
    Leaf{ns, name}(key(a), union(a.attributes, b))

include("htmlvariants.jl")
include("combinators.jl")
include("writers.jl")
include("diff.jl")

end # module
