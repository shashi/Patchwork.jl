import JSON: json

js_runtime() =
    readall(open(joinpath(dirname(@__FILE__), "..", "runtime", "build.js")))

load_js_runtime() =
    display(MIME("text/html"), "<script>$(
        js_runtime()
    )</script>")


pwid() = replace(string(gensym("pwid")), "#", "")

writemime(io::IO, ::MIME"application/json", x::(@compat Union{Node, Patch})) =
    write(io, json(jsonfmt(x)))

function writemime(io::IO, ::MIME"text/html", x::Node)
    id = pwid()
    write(io, """<div id="$id">""",
              """<script>new Patchwork.Node("$id", $(json(jsonfmt(x))));</script>""",
              """</div>""")
end

function refdiff(a, b; label="")
    # Inspect a reference (vtree) diff of two nodes
    display(MIME("text/html"), string("<script>
        console.log('", label, "', Patchwork.refDiff(", json(jsonfmt(a)), ",", json(jsonfmt(b)), ",", json(jsonfmt(diff(a,b))),"));
    </script>"))
end
