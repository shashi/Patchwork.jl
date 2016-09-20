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
       show,
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
       withchild,
       withlastchild,
       TextNode,
       text,
       NodeVector,
       Props,
       props,
       attrs,
       EmptyNode,
       MaybeKey,
       tohtml

typealias MaybeKey Union{Void, Symbol}

# A Patchwork node
abstract Node

immutable TextNode <: Node
    text::AbstractString
end
text(xs...) =
    TextNode(string(xs...))

convert(::Type{Node}, s::AbstractString) = text(s)
promote_rule(::Type{Node}, ::Type{AbstractString}) = Node

# Abstract out the word "Persistent"
typealias NodeVector   PersistentVector{Node}
typealias Props Dict{Any, Any}

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    NodeVector([convert(Node, y) for y in x])

convert(::Type{NodeVector}, x::Node) =
    NodeVector([x])

convert(::Type{NodeVector}, x::NodeVector) =
    x

convert(::Type{NodeVector}, x::AbstractString) =
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

_count(t::TextNode) = 1
_count(el::Elem) = el.count + 1
count(t::TextNode) = 0
count(el::Elem) = el.count
function count(v::NodeVector)
    s = 0
    for x in v
        s +=_count(x)
    end
    s
end

key(n::Elem) = hasproperties(n) ? get(n.properties, :key, nothing) : nothing
key(n::TextNode) = nothing

# constructors
Elem{T}(::Type{T}, ns, name, props, children) =
    Elem{T}(Symbol(ns) , Symbol(name), children, props)

Elem(ns, name, props, children) =
    Elem(DOM, ns, name, props, children)

Elem(ns::Union{Symbol, String}, name::Symbol, children=EmptyNode; kwargs...) =
    Elem(ns, name, kwargs, children)

Elem(name::Union{Symbol, String}, children=EmptyNode; kwargs...) =
    Elem(:xhtml, name, kwargs, children)

Elem(T::Type, name, children=EmptyNode; kwargs...) =
    Elem(T, :xhtml, name, kwargs, children)

isequal{T}(a::Elem{T}, b::Elem{T}) =
    a === b || (isequal(namespace(a), namespace(b)) &&
                isequal(tag(a), tag(b)) &&
                isequal(properties(a), properties(b)) &&
                isequal(children(a), children(b)))

isequal(a::Elem, b::Elem) = false
==(a::TextNode, b::TextNode) = a.text == b.text
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
include("hooks.jl")
include("writers.jl")


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

@compat function Base.show(io::IO, el::TextNode, indent_level=0)
    showindent(io, indent_level)
    show(io, el.text)
end
function showprops(io, dict)
    write(io, "{")
    write(io, ' ')
    for (k,v) in dict
        print(io, k)
        write(io, '=')
        show(io, v)
        write(io, ' ')
    end
    write(io, "}")
end

@compat function Base.show{T}(io::IO, el::Elem{T}, indent_level=0)
    showindent(io, indent_level)
    write(io, "(")
    if namespace(el) != :xhtml
        write(io, namespace(el))
        write(io, ":")
    end
    write(io, tag(el))
    if hasproperties(el)
        write(io, " ")
        showprops(io, properties(el))
    end
    showchildren(io, children(el), indent_level)
    write(io, ")")
end

function __init__()
    if isdefined(Main, :IJulia)
        include(joinpath(dirname(@__FILE__), "ijulia.jl"))
    end
    try
        load_js_runtime()
    catch
    end

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
