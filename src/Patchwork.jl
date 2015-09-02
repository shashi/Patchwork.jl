module Patchwork

using FunctionalCollections
using Compat

import Base:
       convert,
       promote_rule,
       isequal,
       ==,
       >>,
       &,
       writemime,
       <<

export Node,
       Elem,
       dispatch_type,
       namespace,
       tag,
       properties,
       children,
       haschildren,
       hasproperties,
       Text,
       text,
       NodeVector,
       Props,
       props,
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
typealias Props Dict{Any, Any}

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    NodeVector([convert(Node, y) for y in x])

convert{T <: Node}(::Type{NodeVector}, x::T) =
    NodeVector([x])

convert(::Type{NodeVector}, x::NodeVector) =
    x

convert(::Type{NodeVector}, x::String) =
    NodeVector([text(x)])

convert(::Type{Props}, x::AbstractArray) = Props(x)

# the default type parameter of Elem
abstract DOM

# An Element. T is to be used for dispatch
immutable Elem{T} <: Node
    namespace::Symbol
    tag::Symbol
    count::Int
    children::NodeVector
    properties::Props

    function Elem(ns, tag, children, properties)
        childvec = convert(NodeVector, children)
        if isempty(properties)
            new(ns, tag, count(childvec), childvec)
        else
            new(ns, tag, count(childvec), childvec, properties)
        end
    end
end

dispatch_type{T}(el::Elem{T}) = el
namespace(el::Elem) = el.namespace
tag(el::Elem) = el.tag
properties(el::Elem) = isdefined(el, :properties) ? el.properties : Props()
children(el::Elem) = el.children
hasproperties(el::Elem) = isdefined(el, :properties)
haschildren(el::Elem) = !isempty(el.children)

_count(t::Text) = 1
_count(el::Elem) = el.count + 1
count(t::Text) = 0
count(el::Elem) = el.count
count(v::NodeVector) = Int[_count(x) for x in v] |> sum

key(n::Elem) = hasproperties(n) ? get(n.properties, :key, nothing) : nothing
key(n::Text) = nothing

# constructors
Elem{T}(::Type{T}, ns, name, props, children) =
    Elem{T}(symbol(ns) , symbol(name), children, props)

Elem(ns, name, props, children) =
    Elem(DOM, ns, name, props, children)

Elem(ns::Union(Symbol, String), name::Symbol, children=EmptyNode; kwargs...) =
    Elem(ns, name, kwargs, children)

Elem(name::Union(Symbol, String), children=EmptyNode; kwargs...) =
    Elem(:xhtml, name, kwargs, children)

Elem(T::Type, name, children=EmptyNode; kwargs...) =
    Elem(T, :xhtml, name, kwargs, children)

isequal{T}(a::Elem{T}, b::Elem{T}) =
    a === b || (isequal(namespace(a), namespace(b)) &&
                isequal(tag(a), tag(b)) &&
                isequal(properties(a), properties(b)) &&
                isequal(children(a), children(b)))

isequal(a::Elem, b::Elem) = false

==(a::Text, b::Text) = a.text == b.text
=={T}(a::Elem{T}, b::Elem{T}) =
    a === b || (namespace(a) == namespace(b) &&
                tag(a) == tag(b) &&
                properties(a) == properties(b) &&
                children(a) == children(b))

==(a::Elem, b::Elem) = false

# Combining elements
(<<){T}(a::Elem{T}, b::AbstractArray) =
    Elem(T, namespace(a), tag(a), hasproperties(a) ? a.properties : [], append(a.children, b))
(<<){T}(a::Elem{T}, b::Node) =
    Elem(T, namespace(a), tag(a), hasproperties(a) ? a.properties : [], push(a.children, b))

# Manipulating properties
function recmerge(a, b)
    c = Dict{Any, Any}(a)
    for (k, v) in b
        if isa(v, Associative) && haskey(a, k) && isa(a[k], Associative)
            c[k] = recmerge(a[k], v)
        else
            c[k] = b[k]
        end
    end
    c
end

attrs(; kwargs...) = @compat Dict(:attributes => Dict(kwargs))
props(; kwargs...) = kwargs

(&){T}(a::Elem{T}, itr) =
    Elem(T, namespace(a), tag(a), hasproperties(a) ? recmerge(a.properties, itr) : itr , children(a))

withchild{T}(f::Function, elem::Elem{T}, i::Int) = begin
    children = assoc(children(elem), i, f(elem[i]))
    Elem(T, namespace(elem), tag(elem), hasproperties(a) ? a.properties : [], children)
end
withlastchild(f::Function, elem::Elem) =
    withchild(f, elem, length(children(elem)))

include("diff.jl")
include("parse.jl")

include("jsonfmt.jl")
include("writers.jl")

if isdefined(Main, :IJulia)
    include("ijulia.jl")
end

function showchildren(io, elems, indent_level)
    length(elems) == 0 && return
    write(io, "\n")
    l = length(elems)
    for i=1:l
        show(io, elems[i], indent_level+1)
        i != l && write(io, "\n")
    end
end

function showindent(io, level)
    for i=1:level
        write(io, "  ")
    end
end

function Base.show(io::IO, el::Text, indent_level=0)
    showindent(io, indent_level)
    show(io, el.text)
end

function Base.show{T}(io::IO, el::Elem{T}, indent_level=0)
    showindent(io, indent_level)
    write(io, "(")
    if !is(T, DOM)
        show(io, "{", T, "}")
    end
    if namespace(el) != :xhtml
        write(io, namespace(el))
        write(io, ":")
    end
    write(io, tag(el))
    if hasproperties(el)
        write(io, " ")
        show(io, properties(el))
    end
    showchildren(io, children(el), indent_level)
    write(io, ")")
end

end # module
