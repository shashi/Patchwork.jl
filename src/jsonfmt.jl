jsonfmt(x::Text) = [:text => x.text]
jsonfmt{ns, tag}(x::Elem{ns, tag}) =
    [ :namespace => ns
    , :tagName => tag
    , :key => x.key
    , :properties => x.attributes
    , :children => [jsonfmt(c) for c in x.children]
    ]
jsonfmt(x::Nothing) = nothing

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

jsonfmt(p::Overwrite{Text}) = [VPATCH_VTEXT => p.b.text]
jsonfmt(p::Overwrite{Elem}) = [VPATCH_VNODE =>jsonfmt(p.b)]
jsonfmt(p::DictDiff)        = [VPATCH_PROPS => p.updates]
jsonfmt(p::Reorder)         = [VPATCH_ORDER => p.moves]
jsonfmt(p::Insert)          = [VPATCH_INSERT => jsonfmt(p.b)]
jsonfmt(p::Delete)          = [VPATCH_REMOVE => nothing]

jsonfmt(ps::AbstractArray{Patch}) =
    length(ps) == 1 ?
        jsonfmt(ps[1]) :
        [jsonfmt(p) for p in ps]

jsonfmt(ps::Dict) = [k => jsonfmt(p) for (k, p) in ps]
