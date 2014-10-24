using IJulia.CommManager
import IJulia.metadata
import JSON: json
import Reactive: Signal, value, lift

import Base: writemime

include("jsonfmt.jl")

const runtimejs = readall(open(joinpath(Pkg.dir("Patchwork"), "runtime", "build.js")))

display(MIME("text/html"), "<script>$(runtimejs)</script>")

metadata(x::Node) =
    {:reactive => true, :patchwork_id => key(x)}

pwid() = replace(string(gensym("pwid")), "#", "")

function writemime(io::IO, ::MIME"text/html", x::Node)
    id = pwid()
    write(io, """<div id="$id">""",
              """<script>new Patchwork("$id", $(json(jsonfmt(x))));</script>""",
              """</div>""")
end

function refDiff(a, b; label="")
    # Inspect a reference (vtree) diff of two nodes
    display(MIME("text/html"), string("<script>
        console.log('", label, "', Patchwork.refDiff(", json(jsonfmt(a)), ",", json(jsonfmt(b)), "));
    </script>"))
end

function diff(s::Signal)
    prev = value(s)
    lift((x) -> begin
        d = diff(prev, x)
        prev = x
        d
    end, Union(Patch, Nothing), s)
end

function send_patch(comm, d)
    jsonpatch = jsonfmt(d)
    if jsonpatch != nothing
        send_comm(comm, jsonpatch)
    end
end

function writemime{ns, name}(io::IO, ::MIME"text/html", x::Signal{Elem{ns, name}})
    comm = Comm(:Patchwork)
    # Send patch stream
    lift((d) -> send_patch(comm, d), diff(x))

    id = pwid()
    write(io, """<div id="$id">""",
              """<script>new Patchwork("$id", $(json(jsonfmt(value(x)))),
                    {patchComm: "$(comm.id)"});</script>""",
              """</div>""")
end
