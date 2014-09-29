
function make_elems{ns}(variant::HtmlVariant{ns})
    exports = Expr(:export, [variant.parents, variant.leafs]...)
    contents = :(begin end)
    push!(contents.args, exports)
    for tag in variant.parents
        push!(contents.args, quote
            $tag(attrs, content; _key::MaybeKey=nothing) =
                Parent($(string(ns)),
                       $(string(tag)),
                       attrs,
                       content,
                       _key=_key)

            $tag(content=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
                Parent($(string(ns)),
                       $(string(tag)),
                       Base.map(Attr, kwargs),
                       content,
                       _key)

        end)
    end

    for tag in variant.leafs
        push!(contents.args, quote

            $tag(attrs; _key::MaybeKey=nothing) =
                Leaf($(string(ns)), $(string(tag)), attrs, _key)

            $tag(; _key::MaybeKey=nothing, kwargs...) =
                Leaf($(string(ns)),
                $(string(tag)),
                Base.map(Attr, kwargs),
                _key)
        end)
    end
    contents
end

function make_attrs{ns}(variant::HtmlVariant{ns})
    func_name(attr) = symbol(replace(string(attr), "-", "_"))
    exports = Expr(:export, Base.map(func_name, variant.attributes)...)
    contents = :(begin end)
    push!(contents.args, exports)
    for attr in variant.attributes
        func = func_name(attr)
        push!(contents.args, quote
            $func(value) =
                Attr{
                    symbol($(string(ns))),
                    symbol($(string(attr)))
                    }(value)
        end)
    end
    contents
end

# Combinators for HTML5

export HTML5

module HTML5

using Patchwork

export Attributes, document

eval(Patchwork.make_elems(Patchwork.html5))

document(h, b) = Patchwork.document(:HTML5, h, b)
document(x)    = Patchwork.document(:HTML5, x)

module Attributes
using Patchwork
eval(Patchwork.make_attrs(Patchwork.html5))
end
end
