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

convert(::Type{NodeVector}, x::Node) =
    NodeVector([x])

convert(::Type{NodeVector}, x::NodeVector) =
    x

convert(::Type{NodeVector}, x::String) =
    NodeVector([text(x)])

convert(::Type{Props}, x::AbstractArray) = Props(x)

# A DOM Element
immutable Elem{ns, tag} <: Node
    count::Int
    children::NodeVector
    properties::Props

    function Elem(properties, children)
        childvec = convert(NodeVector, children)
        if isempty(properties)
            new(count(childvec), childvec)
        else
            new(count(childvec), childvec, properties)
        end
    end

    function Elem()
        n = new(0, EmptyNode)
    end
end

hasproperties(el::Elem) = isdefined(el, :properties)
haschildren(el::Elem) = !isempty(el.children)
properties(el::Elem) = isdefined(el, :properties) ? el.properties : Props()
children(el::Elem) = el.children

_count(t::Text) = 1
_count(el::Elem) = el.count + 1
count(t::Text) = 0
count(el::Elem) = el.count
count(v::NodeVector) = Int[_count(x) for x in v] |> sum

key(n::Elem) = hasproperties(n) ? get(n.properties, :key, nothing) : nothing
key(n::Text) = nothing

# A document type
immutable DocVariant{ns}
    elements::Vector{Symbol}
end

# constructors
Elem(ns::Symbol, name::Symbol) = Elem{ns, name}()

Elem(ns, name, props, children) =
    Elem{symbol(ns) , symbol(name)}(props, children)

Elem(ns::Symbol, name::Symbol, children=EmptyNode; kwargs...) =
    Elem(ns, name, kwargs, children)

Elem(name, children=EmptyNode; kwargs...) =
    Elem(:xhtml, name, kwargs, children)

isequal{ns,name}(a::Elem{ns,name}, b::Elem{ns,name}) =
    a === b || (isequal(properties(a), properties(b)) &&
                isequal(children(a), children(b)))
isequal(a::Elem, b::Elem) = false

==(a::Text, b::Text) = a.text == b.text
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
    children = assoc(children(elem), i, f(elem[i]))
    Elem(ns, name, hasproperties(a) ? a.properties : [], children)
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

end # module
