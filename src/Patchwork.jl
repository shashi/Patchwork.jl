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
       text,
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

immutable Text <: Node
    text::ByteString
end
text(xs...) =
    Text(string(xs...))

convert(::Type{Node}, s::String) = text(s)
promote_rule(::Type{Node}, ::Type{String}) = Node

# Abstract out the word "Persistent"
typealias NodeVector   PersistentVector{Node}
typealias Attrs PersistentHashMap{Any, Any}

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    NodeVector([convert(Node, y) for y in x])

convert{T <: Node}(::Type{NodeVector}, x::T) =
    NodeVector([x])

convert(::Type{NodeVector}, x::NodeVector) =
    x

convert(::Type{NodeVector}, x::String) =
    NodeVector([text(x)])

convert(::Type{Attrs}, x::PersistentHashMap) = x
function convert(::Type{Attrs}, x)
    a = Attrs()
    for (k, v) in x
        a = assoc(a, k, v)
    end
    a
end

# A DOM Element
immutable Elem{ns, tag} <: Node
    count::Int
    attributes::Attrs
    children::NodeVector

    function Elem(attributes, children)
        childvec = convert(NodeVector, children)
        new(count(childvec),
            convert(Attrs, attributes),
            childvec)
    end
end

_count(t::Text) = 1
_count(el::Elem) = el.count
count(t::Text) = 0
count(el::Elem) = el.count
count(v::NodeVector) = Int[_count(x) for x in v] |> sum

key(n::Elem) = get(n.attributes, :key, nothing)
key(n::Text) = nothing

# A document type
immutable DocVariant{ns}
    elements::Vector{Symbol}
end

# constructors
Elem(ns, name, attrs, children) =
    Elem{symbol(ns) , symbol(name)}(attrs, children)

Elem(ns, name, children=EmptyNode; kwargs...) =
    Elem(ns, name, kwargs, children)

Elem(name, children=EmptyNode; kwargs...) =
    Elem(:xhtml, name, kwargs, children)

isequal{ns,name}(a::Elem{ns,name}, b::Elem{ns,name}) =
    a === b || (isequal(a.attributes, b.attributes) &&
                sequal(a.children, b.children))
isequal(a::Elem, b::Elem) = false

==(a::Text, b::Text) = a.text == b.text
=={ns, name}(a::Elem{ns, name}, b::Elem{ns,name}) =
    a === b || (a.attributes == b.attributes &&
                a.children == b.children)
==(a::Elem, b::Elem) = false

# Combining elements
(<<){ns, tag}(a::Elem{ns, tag}, b::AbstractArray) =
    Elem{ns, tag}(a.attributes, append(a.children, b))
(<<){ns, tag}(a::Elem{ns, tag}, b::Node) =
    Elem{ns, tag}(a.attributes, push(a.children, b))

# Manipulating attributes
attrs(; kwargs...) = kwargs
(&){ns, name}(a::Elem{ns, name}, itr) =
    Elem{ns, name}(merge(a.attributes, itr), a.children)

include("variants.jl")
include("combinators.jl")
include("writers.jl")
include("diff.jl")

if isdefined(Main, :IJulia)
    include("ijulia.jl")
end

end # module
