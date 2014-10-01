export diff

using Debug

abstract Patch
type Replace <: Patch
    a
    b
end

type VectorDiff <: Patch
    moves
    inserts
    deletes
end
VectorDiff() = VectorDiff(Dict(), Dict(), Dict())

function writestring(io::IO, d::VectorDiff)
    for (x, y) in d.moves
        write(io, string(x), " |> ", y[1], " # ", y[2], "\n")
    end
    for (i, x) in [d.inserts]
        write(io, string(i), " +> ")
        writestring(io, x)
        write(io, "\n")
    end
    for (i, x) in [d.deletes]
        write(io, string(i), " -> ")
        writestring(io, x)
        write(io, "\n")
    end
end

function key_idxs(ns)
    i = 1
    idxs = Dict()
    for x in ns
        if key(x) != nothing
            idxs[key(x)] = i
        end
        i += 1
    end
    idxs
end

function diff(a::NodeVector, b::NodeVector)
    if a === b return nothing end

    if length(a) == 1 && length(b) == 1
        return diff(a[1], b[1])
    end

    n = max(length(a), length(b))
    a_key_idxs = key_idxs(a)
    b_key_idxs = key_idxs(b)

    patch = VectorDiff()
    for i = 1:length(a)
        moved_to = get(b_key_idxs, key(a[i]), 0)
        if moved_to == 0
            patch.deletes[i] = Delete(a[i])
        else
            d = diff(a[i], b[moved_to])
            if i == moved_to && d == nothing continue end
            patch.moves[i] = (moved_to, d)
        end
    end

    for i = 1:length(b)
        moved_from = get(a_key_idxs, key(b[i]), 0)
        if moved_from == 0
            patch.inserts[i] = Insert(b[i])
        end
    end
    patch
end

function writestring(io::IO, p::Replace)
    write(io, "- ")
    writehtml(io, p.a)
    write("\n+ ")
    writehtml(io, p.b)
end

type ElemDiff <: Patch
    a
    attributes
    children
end

function writestring(io::IO, p::ElemDiff)
    write(io, "~ ", tohtml(p.a))
    writestring(io, p.attributes)
    writestring(io, p.children)
end

type AttrDiff <: Patch
    added
    deleted
end

function writestring(io::IO, p::AttrDiff)
    write(io, "\n- ")
    map(a -> writehtml(io, a), p.deleted)
    write(io, "\n+ ")
    map(a -> writehtml(io, a), p.added)
end

type Insert <: Patch
    b
end

function writestring(io::IO, p::Insert)
    write(io, "I ")
    writehtml(io, p.b)
end

type Delete <: Patch
    a
end

function writestring(io::IO, p::Delete)
    write(io, "D ")
    writehtml(io, p.a)
end

function writestring(io::IO, ps::AbstractArray{Patch})
    for p in ps
        writestring(io, p)
    end
end

function writestring(io::IO, x)
    write(io, string(x))
end

function tostring(p::Patch)
    io = IOBuffer()
    writestring(io, p)
    takebuf_string(io)
end

function diff(a::Union(PCDATA, CDATA), b::Union(PCDATA, CDATA))
    if a === b || a.value == b.value
        return nothing
    end
    return Replace(a, b)
end

function diff{ns, tag}(a::Parent{ns, tag}, b::Parent{ns, tag})
    if a === b return nothing end

    attributes = diff(a.attributes, b.attributes)
    children   = diff(a.children, b.children)
    if !is(attributes, nothing) || !is(children, nothing)
        return ElemDiff(a, attributes, children)
    end
end

function diff{ns, tag}(a::Leaf{ns, tag}, b::Leaf{ns, tag})
    if a === b return nothing end

    attributes = diff(a.attributes, b.attributes)
    if !is(attributes, nothing)
        return ElemDiff(a, attributes, nothing)
    end
end

diff(a::Elem, b::Elem) =
    Replace(a, b)

function diff(a::Attrs, b::Attrs)
    if a === b return nothing end

    added = setdiff(b, a)
    deleted = setdiff(a, b)
    if length(added) != 0 || length(deleted) != 0
        return AttrDiff( added, deleted)
    end
end
