using IJulia.CommManager
import IJulia.metadata
import JSON: json
using Patchwork
using Compat

if Pkg.installed("Reactive") !=nothing && Pkg.installed("Reactive") >= v"0.1.9"
    import Reactive: Signal, value, preserve

    function diff(s::Signal)
        prev = value(s)
        map((x) -> begin
            d = Patchwork.diff(prev, x)
            prev = x
            d
        end, s)
    end

    function send_patch(comm, d)
        jsonpatch = Patchwork.jsonfmt(d)
        if !isempty(jsonpatch)
            send_comm(comm, jsonpatch)
        end
    end

    metadata{ns, name}(x::Signal{Elem{ns, name}}) = Dict()

    @compat function Base.show{ns, name}(io::IO, ::MIME"text/html", x::Signal{Elem{ns, name}})
        id = Patchwork.pwid()

        write(io, """<div id="$id">""",
                  """<script>new Patchwork.Node("$id", $(json(Patchwork.jsonfmt(value(x)))));</script>""",
                  """</div>""")

        comm = Comm(:PatchStream; data=Dict(:pwid => id))
        # lift patch stream
        map((d) -> send_patch(comm, d), diff(x)) |> preserve
    end
end
