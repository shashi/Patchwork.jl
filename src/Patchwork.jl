module Patchwork

using FunctionalCollections

import Base: convert, promote_rule, isequal, ==, >>, &
import FunctionalCollections.AbstractList

export Attr, Node, Elem, CDATA, PCDATA, NodeList, Attrs, EmptyNode,
       attr, Parent, Leaf

# A Patchwork node

abstract Node

immutable CDATA <: Node
    value::ByteString
end

immutable PCDATA <: Node
    value::ByteString
end
pcdata(xs...) = PCDATA(string(xs...))

convert(::Type{Node}, s::String) = pcdata(s)
promote_rule(::Type{Node}, ::Type{String}) = Node

# An attribute

immutable Attr{ns, name}
    value
end

# Abstract out the word "Persistent"

typealias NodeList   AbstractList{Node}
typealias Attrs PersistentSet{Attr}
typealias EmptyNode  EmptyList{Node}

convert(::Type{NodeList}, x) =
    PersistentList{Node}(x)
convert(::Type{NodeList}, x::String) =
    PersistentList{Node}([PCDATA(x)])
convert(::Type{Attrs}, x) =
    Attrs(x)

# An XML/HTML element
abstract Elem{ns, name} <: Node

# HTML5 requires a distinction between parent and leaf nodes.
immutable Parent{ns, name} <: Elem{ns, name}
    attributes::Attrs
    children::NodeList
end

immutable Leaf{ns, name} <: Elem{ns, name}
    attributes::Attrs
end

# constructors

Attr(ns, name, val) = Attr{symbol(ns), symbol(name)}(val)
Attr(x::(Any, Any)) = Attr{None, symbol(x[1])}(x[2])

Parent(ns, name, attrs, children) =
    Parent{is(ns, None) ? ns : symbol(ns) , symbol(name)}(attrs, children)
Parent(ns, name, children=EmptyNode(); kwargs...) =
    Parent{symbol(ns), symbol(name)}(Attr[map(Attr, kwargs)...], children)
Parent(name, children=EmptyNode(); kwargs...) =
    Parent{None, symbol(name)}(Attr[map(Attr, kwargs)...], children)

Leaf(ns, name, attrs) =
    Leaf{is(ns, None) ? ns : symbol(ns) , symbol(name)}(attrs)
Leaf(ns, name; kwargs...) =
    Leaf{symbol(ns), symbol(name)}(Attr[map(Attr, kwargs)...])
Leaf(name; kwargs...) =
    Leaf{None, symbol(name)}(Attr[map(Attr, kwargs)...])

isequal{ns,name}(a::Parent{ns,name}, b::Parent{ns,name}) =
    a === b || (isequal(a.attributes, b.attributes) &&
                sequal(a.children, b.children))
isequal(a::Parent, b::Parent) = false
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

# Combining Elements

(>>)(a::Union(Node, String), b::Union(Node, String)) = convert(NodeList, (convert(Node, b), convert(Node, a)))
(>>)(a::NodeList, b) = cons(convert(Node, b), a)
(>>)(a, b::NodeList) = # should probably not allow this
    reverse(cons(convert(Node, a), reverse(b)))
(>>)(a::NodeList, b::NodeList) = reduce(cons, a, reverse(b))

(&){ns, name}(a::Parent{ns, name}, b::Union(Attr, Attrs)) =
    Parent{ns, name}(union(a.attributes, b), a.children)
(&){ns, name}(a::Leaf{ns, name}, b::Union(Attr, Attrs)) =
    Leaf{ns, name}(union(a.attributes, b))

include("htmlvariants.jl")
include("combinators.jl")

end # module
