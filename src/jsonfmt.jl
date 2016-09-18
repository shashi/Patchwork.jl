# Concise JSON representations

jsonfmt(x::TextNode) = Dict(:txt => x.text)

function jsonfmt{ns, tag}(x::Elem{ns, tag})
    dict = Dict{Any, Any}('t' => tag)
    if ns !== :xhtml
        dict['n'] = ns
    end
    if hasproperties(x)
        dict['p'] = properties(x)
    end
    if haschildren(x)
        dict['c'] = [jsonfmt(c) for c in x.children]
    end
    dict
end
jsonfmt(::Void) = nothing

# values from vtree/vpatch.js
const VPATCH_NONE = 0
const VPATCH_VTEXT = 1
const VPATCH_VNODE = 2
# const VPATCH_WIDGET = 3
const VPATCH_PROPS = 4
const VPATCH_ORDER = 5
const VPATCH_INSERT = 6
const VPATCH_REMOVE = 7
# const VPATCH_THUNK = 8

jsonfmt{T <: Elem}(p::Overwrite{T}) = Dict(VPATCH_VNODE =>jsonfmt(p.b))
jsonfmt(p::Overwrite{TextNode}) = Dict(VPATCH_VTEXT => p.b.text)
jsonfmt(p::DictDiff)        = Dict(VPATCH_PROPS => p.updates)
jsonfmt(p::Reorder)         = Dict(VPATCH_ORDER => p.moves)
jsonfmt(p::Insert)          = Dict(VPATCH_INSERT => jsonfmt(p.b))
jsonfmt(p::Delete)          = Dict(VPATCH_REMOVE => nothing)

jsonfmt(ps::AbstractArray{Patch}) =
    length(ps) == 1 ?
        jsonfmt(ps[1]) :
        [jsonfmt(p) for p in ps]

function jsonfmt(ps::Dict)
    d=Dict()
    for (k,p) in ps
        d[k]=jsonfmt(p)
    end
    d
end
