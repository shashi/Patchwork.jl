using IJulia.CommManager
import IJulia.metadata
import JSON: json
import Reactive: Signal, value, lift

import Base: writemime

include("jsonfmt.jl")

load_js_runtime() =
    display(MIME("text/html"), "<script>$(
        readall(open(joinpath(Pkg.dir("Patchwork"), "runtime", "build.js")))
    )</script>")
    
load_js_runtime()


pwid() = replace(string(gensym("pwid")), "#", "")

function writemime(io::IO, ::MIME"text/html", x::Node)
    id = pwid()
    write(io, """<div id="$id">""",
              """<script>new Patchwork.Node("$id", $(json(jsonfmt(x))));</script>""",
              """</div>""")
end

function refDiff(a, b; label="")
    # Inspect a reference (vtree) diff of two nodes
    display(MIME("text/html"), string("<script>
        console.log('", label, "', Patchwork.refDiff(", json(jsonfmt(a)), ",", json(jsonfmt(b)), ",", json(jsonfmt(diff(a,b))),"));
    </script>"))
end

function diff(s::Signal)
    prev = value(s)
    lift((x) -> begin
        d = diff(prev, x)
        prev = x
        d
    end, s)
end

function send_patch(comm, d)
    jsonpatch = jsonfmt(d)
    if !isempty(jsonpatch)
        send_comm(comm, jsonpatch)
    end
end

metadata{ns, name}(x::Signal{Elem{ns, name}}) = Dict()

function writemime{ns, name}(io::IO, ::MIME"text/html", x::Signal{Elem{ns, name}})
    id = pwid()

    write(io, """<div id="$id">""",
              """<script>new Patchwork.Node("$id", $(json(jsonfmt(value(x)))));</script>""",
              """</div>""")

    comm = Comm(:PatchStream; data=[:pwid => id])
    # lift patch stream
    lift((d) -> send_patch(comm, d), diff(x))
end
