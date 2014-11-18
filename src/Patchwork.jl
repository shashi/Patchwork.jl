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
       writemime

export Node,
       Elem,
       attributes,
       children,
       Text,
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
typealias Attrs Dict{Any, Any}

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    NodeVector([convert(Node, y) for y in x])

convert{T <: Node}(::Type{NodeVector}, x::T) =
    NodeVector([x])

convert(::Type{NodeVector}, x::NodeVector) =
    x

convert(::Type{NodeVector}, x::String) =
    NodeVector([text(x)])

convert(::Type{Attrs}, x::AbstractArray) = Attrs(x)

# A DOM Element
immutable Elem{ns, tag} <: Node
    count::Int
    children::NodeVector
    attributes::Attrs

    function Elem(attributes, children)
        childvec = convert(NodeVector, children)
        if isempty(attributes)
            new(count(childvec), childvec)
        else
            new(count(childvec), childvec, attributes)
        end
    end

    function Elem()
        n = new(0, EmptyNode)
    end
end

hasattributes(el::Elem) = isdefined(el, :attributes)
haschildren(el::Elem) = !isempty(el.children)
attributes(el::Elem) = isdefined(el, :attributes) ? el.attributes : Attrs()
children(el::Elem) = el.children

_count(t::Text) = 1
_count(el::Elem) = el.count + 1
count(t::Text) = 0
count(el::Elem) = el.count
count(v::NodeVector) = Int[_count(x) for x in v] |> sum

key(n::Elem) = hasattributes(n) ? get(n.attributes, :key, nothing) : nothing
key(n::Text) = nothing

# A document type
immutable DocVariant{ns}
    elements::Vector{Symbol}
end

# constructors
Elem(ns::Symbol, name::Symbol) = Elem{ns, name}()

Elem(ns, name, attrs, children) =
    Elem{symbol(ns) , symbol(name)}(attrs, children)

Elem(ns::Symbol, name::Symbol, children=EmptyNode; kwargs...) =
    Elem(ns, name, kwargs, children)

Elem(name, children=EmptyNode; kwargs...) =
    Elem(:xhtml, name, kwargs, children)

isequal{ns,name}(a::Elem{ns,name}, b::Elem{ns,name}) =
    a === b || (isequal(attributes(a), attributes(b)) &&
                sequal(children(a), children(b)))
isequal(a::Elem, b::Elem) = false

==(a::Text, b::Text) = a.text == b.text
=={ns, name}(a::Elem{ns, name}, b::Elem{ns,name}) =
    a === b || (a.attributes == b.attributes &&
                a.children == b.children)
==(a::Elem, b::Elem) = false

# Combining elements
(<<){ns, tag}(a::Elem{ns, tag}, b::AbstractArray) =
    Elem{ns, tag}(hasattributes(a) ? a.attributes : [], append(a.children, b))
(<<){ns, tag}(a::Elem{ns, tag}, b::Node) =
    Elem{ns, tag}(hasattributes(a) ? a.attributes : [], push(a.children, b))

# Manipulating attributes
attrs(; kwargs...) = kwargs
(&){ns, name}(a::Elem{ns, name}, itr) =
    Elem{ns, name}(hasattributes(a) ? merge(a.attributes, itr) : itr , children(a))

include("variants.jl")
include("combinators.jl")
include("diff.jl")
include("parse.jl")

include("jsonfmt.jl")
include("writers.jl")

if isdefined(Main, :IJulia)
    include("ijulia.jl")
end

const compose_version = try Pkg.installed("Compose") catch v"0.0.0" end
if compose_version > v"0.0.0"
    include("compose_backend.jl")
end

end # module
