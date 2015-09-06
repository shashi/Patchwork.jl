using IJulia.CommManager
import IJulia.metadata
import JSON: json

import Base: writemime

if Pkg.installed("Reactive") !=nothing && Pkg.installed("Reactive") >= v"0.1.9"
    import Reactive: Signal, value, lift

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

        comm = Comm(:PatchStream; data=@compat Dict(:pwid => id))
        # lift patch stream
        lift((d) -> send_patch(comm, d), diff(x))
    end
end
