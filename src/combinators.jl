export HTML5, SVG

function make_elems{ns}(variant::DocVariant{ns})
    exports = Expr(:export, variant.elements...)
    contents = :(begin end)
    push!(contents.args, exports)
    for tag in variant.elements
        push!(contents.args, quote
            $tag(content; kwargs...) =
                Elem($(string(ns)),
                     $(string(tag)),
                     kwargs,
                     content)

            $tag(content...; kwargs...) =
                Elem($(string(ns)),
                     $(string(tag)),
                     kwargs,
                     content)

        end)
    end
    contents
end

# Combinators for HTML5

module HTML5

using Patchwork

import Base.div

eval(Patchwork.make_elems(Patchwork.html5))

end

# Combinators for SVG

module SVG

using Patchwork

eval(Patchwork.make_elems(Patchwork.svg))

end
