# Concise JSON representations

jsonfmt(x::Text) = [:txt => x.text]
function jsonfmt{ns, tag}(x::Elem{ns, tag})
    dict = @compat Dict{Any, Any}('t' => tag)
    if ns !== :xhtml
        dict['n'] = ns
    end
    if hasattributes(x)
        dict['p'] = attributes(x)
    end
    if haschildren(x)
        dict['c'] = [jsonfmt(c) for c in x.children]
    end
    dict
end
jsonfmt(::Nothing) = nothing

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

jsonfmt(p::Overwrite{Text}) = @compat Dict(VPATCH_VTEXT => p.b.text)
jsonfmt(p::Overwrite{Elem}) = @compat Dict(VPATCH_VNODE =>jsonfmt(p.b))
jsonfmt(p::DictDiff)        = @compat Dict(VPATCH_PROPS => p.updates)
jsonfmt(p::Reorder)         = @compat Dict(VPATCH_ORDER => p.moves)
jsonfmt(p::Insert)          = @compat Dict(VPATCH_INSERT => jsonfmt(p.b))
jsonfmt(p::Delete)          = @compat Dict(VPATCH_REMOVE => nothing)

jsonfmt(ps::AbstractArray{Patch}) =
    length(ps) == 1 ?
        jsonfmt(ps[1]) :
        [jsonfmt(p) for p in ps]

jsonfmt(ps::Dict) = [k => jsonfmt(p) for (k, p) in ps]
