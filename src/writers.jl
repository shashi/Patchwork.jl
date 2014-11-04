import JSON: json

load_js_runtime() =
    display(MIME("text/html"), "<script>$(
        readall(open(joinpath(Pkg.dir("Patchwork"), "runtime", "build.js")))
    )</script>")

try
    load_js_runtime()
catch
end


pwid() = replace(string(gensym("pwid")), "#", "")

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
