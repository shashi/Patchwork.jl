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

const MaybeKey = @compat Union{(@compat Void), Symbol}

# A Patchwork node
@compat abstract type Node end

immutable TextNode <: Node
    text::AbstractString
end
text(xs...) =
    TextNode(string(xs...))

convert(::Type{Node}, s::AbstractString) = text(s)
promote_rule(::Type{Node}, ::Type{AbstractString}) = Node

# Abstract out the word "Persistent"
const NodeVector = PersistentVector{Node}
const Props = Dict{Any, Any}

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

# A DOM Element
immutable Elem{ns, tag} <: Node
    count::Int
    children::NodeVector
    properties::Props
end

function (::Type{Elem{ns, tag}}){ns, tag}(properties, children)
    childvec = convert(NodeVector, children)
    if isempty(properties)
        Elem{ns,tag}(count(childvec), childvec, Props())
    else
        Elem{ns,tag}(count(childvec), childvec, properties)
    end
end

(::Type{Elem{ns, tag}}){ns, tag}() = Elem{ns,tag}(0, EmptyNode)

hasproperties(el::Elem) = isdefined(el, :properties)
haschildren(el::Elem) = !isempty(el.children)
properties(el::Elem) = isdefined(el, :properties) ? el.properties : Props()
children(el::Elem) = el.children

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

# A document type
immutable DocVariant{ns}
    elements::Vector{Symbol}
end

# constructors

Elem(ns, name, props, children) =
    Elem{Symbol(ns) , Symbol(name)}(props, children)

Elem(ns::Symbol, name::Symbol, children=EmptyNode; kwargs...) =
    Elem(ns, name, kwargs, children)

Elem(name, children=EmptyNode; kwargs...) =
    Elem(:xhtml, name, kwargs, children)

isequal{ns,name}(a::Elem{ns,name}, b::Elem{ns,name}) =
    a === b || (isequal(properties(a), properties(b)) &&
                isequal(children(a), children(b)))
isequal(a::Elem, b::Elem) = false

==(a::TextNode, b::TextNode) = a.text == b.text
=={ns, name}(a::Elem{ns, name}, b::Elem{ns,name}) =
    a === b || (a.properties == b.properties &&
                a.children == b.children)
==(a::Elem, b::Elem) = false

# Combining elements
(<<){ns, tag}(a::Elem{ns, tag}, b::AbstractArray) =
    Elem{ns, tag}(hasproperties(a) ? a.properties : [], append(a.children, b))
(<<){ns, tag}(a::Elem{ns, tag}, b::Node) =
    Elem{ns, tag}(hasproperties(a) ? a.properties : [], push(a.children, b))

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

(&){ns, name}(a::Elem{ns, name}, itr) =
    Elem{ns, name}(hasproperties(a) ?
        recmerge(a.properties, itr) : itr , children(a))

withchild{ns, name}(f::Function, elem::Elem{ns, name}, i::Int) = begin
    cs = children(elem)
    cs′ = assoc(cs, i, f(cs[i]))
    Elem(ns, name, hasproperties(elem) ? elem.properties : [], cs′)
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

@compat function Base.show{ns, tag}(io::IO, el::Elem{ns, tag}, indent_level=0)
    showindent(io, indent_level)
    write(io, "(")
    if namespace(el) != :xhtml
        write(io, namespace(el))
        write(io, ":")
    end
    write(io, tag)
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

end # module
