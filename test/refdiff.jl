using Compat
using Patchwork
import Patchwork: jsonfmt, refdiff

# Compare diffs produced by
# Patchwork and virtual-dom
# This prints stuff in the JS console as well

macro compare(a, b)
    hint = string("<> ", a, " -> ", b)
    quote
        refdiff($(esc(a)), $(esc(b)), label=$hint)
        println($hint)
        println(jsonfmt(diff($(esc(a)), $(esc(b)))))
    end
end

a = em("x")
b = a & @compat Dict(:className => "cls")

p,q,r = li("p"), li("q"), li("r")

@compare a a
@compare span(a) span(a, "a")
@compare span(a, "a") span(a)
@compare span(a, "a") span(a, "b")
@compare span(a, "a", b) span(a, "a")
@compare a b
@compare a & @compat Dict(:style => [:color => "red"]) a & Dict(:style => [:color => "blue"])
@compare b a
@compare em(a) em(a)
@compare em(a) em(b)
@compare em(b) em(a)
@compare span([a, b]) span([a, b])
@compare span([a, b]) span([b, a])
@compare ul(p, q, r) ul(p, q, r)
@compare ul(p, q, r) ul(p, r)
@compare ul(p, ul(q, q), r) ul(p, ul(q, q), r)
@compare ul(p, ul(q, q), r) ul(p, ul(q, q & attrs(className="clas")), r & attrs(id="id"))
@compare ul(p, ul(q, q, key=symbol("12")), r) ul(p, ul(q, q, key=symbol("12"))  & attrs(className="clas")+ r & attrs(id="id"))
@compare ul(p, q, r) ul(p, r)
@compare ul(p, r) ul(p, q, r)
@compare ul(p, r) ul(p, q)
@compare ul(p, r) ul(q, p)
@compare ul(p, r) ul(q, p & attrs(className="cls"))
