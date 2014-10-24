jsonfmt(x::Text) = [:text => x.text]
jsonfmt{ns, tag}(x::Elem{ns, tag}) =
    [ :namespace => ns
    , :tagName => tag
    , :key => x.key
    , :properties => x.attributes
    , :children => [jsonfmt(c) for c in x.children]
    ]
jsonfmt(x::Nothing) = nothing

const VPATCH_NONE = 0
const VPATCH_VTEXT = 1
const VPATCH_VNODE = 2
const VPATCH_WIDGET = 3
const VPATCH_PROPS = 4
const VPATCH_ORDER = 5
const VPATCH_INSERT = 6
const VPATCH_REMOVE = 7
const VPATCH_THUNK = 8

#function VirtualPatch(type, vNode, patch) {
#    this.type = Number(type)
#    this.vNode = vNode
#    this.patch = patch
#}
