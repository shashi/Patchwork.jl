using IJulia.CommManager
import IJulia.metadata
import JSON: json

import Base: writemime

const runtimejs = readall(open(joinpath(Pkg.dir("Patchwork"), "runtime", "build.js")))

dict(x::Text) = [:text => x.text]
dict{ns, tag}(x::Elem{ns, tag}) =
    [ :namespace => ns
    , :tagName => tag
    , :key => x.key
    , :properties => x.attributes
    , :children => [dict(c) for c in x.children]
    ]

display(MIME("text/html"), "<script>$(runtimejs)</script>")

metadata(x::Node) =
    {:reactive => true, :patchwork_id => key(x)}

pwid() = replace(string(gensym("pwid")), "#", "")

function writemime(io::IO, ::MIME"text/html", x::Node)
    id = pwid()
    write(io, """<div id="$id">""",
              """<script>Patchwork.render("$id", $(json(dict(x))));</script>""",
              """</div>""")
end
