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

type ElemDiff <: Patch
    a
    attributes
    children
end

type DictDiff <: Patch
    added
    updated
    deleted
end

type Insert <: Patch
    b
end

type Delete <: Patch
    a
end

function diff(a::Text, b::Text)
    if a === b || a.value == b.value
        return nothing
    end
    return Replace(a, b)
end

function diff{ns, tag}(a::Elem{ns, tag}, b::Elem{ns, tag})
    if a === b return nothing end

    attributes = diff(a.attributes, b.attributes)
    children   = diff(a.children, b.children)
    if !is(attributes, nothing) || !is(children, nothing)
        return ElemDiff(a, attributes, children)
    end
end

function diff(a::Associative, b::Associative)
    if a === b return nothing end

    added = Any[]
    updated = Any[]
    deleted = Any[]
    for (k, v) in a
        if k in b
            if is(v != b[k])
                if isa(b[k], Associative)
                    push!(updated, (k, diff(v, b[k])))
                else
                    push!(updated, (k, b[k]))
                end
            end
        else
            push!(deleted, k)
        end
    end
    for (k, v) in b
        if k in a continue end
        push!(added, (k, v))
    end
    if isempty(added) && isempty(updated) && isempty(deleted)
        return nothing
    else
        DictDiff(added, updated, deleted)
    end
end

# Pretty printing diffs
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

function writestring(io::IO, p::Replace)
    write(io, "- ")
    writehtml(io, p.a)
    write("\n+ ")
    writehtml(io, p.b)
end

function writestring(io::IO, p::ElemDiff)
    write(io, "~ ", tohtml(p.a))
    writestring(io, p.attributes)
    writestring(io, p.children)
end

function writestring(io::IO, p::DictDiff)
    write(io, "\n- ")
    map(a -> writehtml(io, a), p.deleted)
    write(io, "\n+ ")
    map(a -> writehtml(io, a), p.added)
end

function writestring(io::IO, p::Insert)
    write(io, "I ")
    writehtml(io, p.b)
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

