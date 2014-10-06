using Patchwork, Patchwork.HTML5
#using Match
using Base.Test

import Patchwork:
           Patch,
           ElemDiff,
           AttrDiff,
           VectorDiff,
           Text,
           Replace,
           Insert,
           Delete

function test_match(x, pattern)
    if string(x) != string(pattern)
        println("Mismatch:")
        println(x)
        println(pattern)
        return false
    end
    true
    #@match x begin
    #    pattern => true
    #    _ => false
    #end
end

# Single child elements

# No difference
e1 = p("a")
@test diff(e1, p("a")) == nothing

d1 = diff(e1, p("b"))
# diff.a must be e1
@test d1.a === e1

# Diff children diff is just diff of the sole child
@test test_match(
    d1,
    ElemDiff(p("a"),
             nothing,
             Replace(text("a"),
                     text("b"))))

# Attribute diffs
a1 = attrs(id="a", class="b")
e2 = e1 & a1

@test diff(e2, e2) == nothing

d2 = diff(e1, e2)
@test d2.children == nothing
@test test_match(d2.attributes,
                 AttrDiff(a1, attrs()))

@test test_match(diff(e2,e1).attributes,
                 AttrDiff(attrs(), a1))

# Vector diffs

l1 = ul(li("1", _key=:a) >>
        li("2", _key=:b) >>
        li("3", _key=:c))

l2 = ul(li("1", _key=:a) >>
        li("2", _key=:b) >>
        li("3", _key=:c))

@test test_match(diff(l1, l2).children,
                 VectorDiff(Dict(), Dict(),Dict()))

l3 = ul(li("3", _key=:c) >>
        li("1", _key=:a) >>
        li("2", _key=:b))

@test test_match(diff(l1, l3).children,
                 VectorDiff({1=>(2,nothing),2=>(3,nothing),3=>(1,nothing)},
                            Dict(),Dict()))
l4 = ul(li("3", _key=:c) >>
        li("1", _key=:a) >>
        li("4", _key=:d) >>
        li("2", _key=:b))

@test test_match(diff(l1, l4).children,
                 VectorDiff({1=>(2,nothing),2=>(4,nothing),3=>(1,nothing)},
                            {3=>Insert(li("4", _key=:d))},Dict()))

l5 = ul(li("C", _key=:c) >>
        li("4", _key=:d) >>
        li("2", _key=:b))

i3 = li("3", _key=:c)
C = li("C", _key=:c)

@test diff(l1, l5).attributes == nothing
@test test_match(diff(l1, l5).children,
                 VectorDiff({2=>(3,nothing),3=>(1,diff(i3, C))},
                            {2=>Insert(li("4", _key=:d))},
                            {1=>Delete(li("1", _key=:a))}))
