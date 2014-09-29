export diff

abstract Patch
type Replace <: Patch
    a
    b
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
    a
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

type Reorder <: Patch
    a
    moves
end
writestring(io::IO, p::Reorder) =
    write(io, "| ", tohtml(p.a), moves)

function writestring(io::IO, ps::AbstractArray{Patch})
    for p in ps
        writestring(io, p)
    end
end

function writestring(io::IO, x)
    write(io, "Unknown: ", string(x))
end

function tostring(p::Patch)
    io = IOBuffer()
    writestring(io, p)
    takebuf_string(io)
end

function diff(a::Union(PCDATA, CDATA), b::Union(PCDATA, CDATA))
    if a !== b || a != b
        return Replace(a, b)
    end
end

function diff{ns, tag}(a::Parent{ns, tag}, b::Parent{ns, tag})
    attributes = diff(a, a.attributes, b.attributes)
    children   = diff(a.children, b.children)
    if !is(attributes, nothing) || !is(children, nothing)
        return ElemDiff(a, attributes, children)
    end
end

function diff{ns, tag}(a::Leaf{ns, tag}, b::Leaf{ns, tag})
    attributes = diff(a.attributes, b.attributes)
    if !is(attributes, nothing)
        return ElemDiff(a, attributes, nothing)
    end
end

diff(a::Elem, b::Elem) =
    Replace(a, b)

function position_map(a)
    keys = Dict()
    i = 1
    for x in a
        if isa(x, Elem) && a[i]._key != nothing
            keys[x._key] = i
        end
        i += 1
    end
    keys
end

function reorder(a::NodeVector, b::NodeVector)

    # First prepare to answer the question
    # Where is the element x in the list y?
    a_idxs = position_map(a)
    b_idxs = position_map(b)

    # Create maps from
    # ListA position -> ListB position &
    # ListB position -> ListA position
    wentfrom_a = Dict()
    wentfrom_b = Dict()

    for (x, i) in b_idxs
        wentfrom_b[i] = a_idxs[x]
    end
    for (x, i) in a_idxs
        wentfrom_a[i] = b_idxs[x]
    end

    n = max(length(a), length(b))

    move_idx = 1
    moves = Dict()
    reverse = Dict()
    shuffle = Union(Node, Nothing)[]        # holds the reordered list
    free_idx = 1

    i = 1 # loop counter
    while free_idx < n
        move = get(wentfrom_a, i, 0)

        # note: push!(shuffle, x) === shuffle[i] = x
        if move != 0                # i.e. a[i] is present in b
            push!(shuffle, b[move]) # place it where it will be compared
            if (move != move_idx)   
                moves[move] = move_idx
                reverse[move_idx] = move
            end
            move_idx += 1
        elseif (i in wentfrom_a) # a[i] is not in b
            push!(shuffle, nothing)
            removes[i] = move_idx
            move_idx += 1
        else
            while get(wentfrom_b, free_idx, 0) != 0
                free_idx += 1
            end
            if free_idx < n
                if length(b) <= free_idx
                    shuffle[i] = b[free_idx] # OKAY.........
                    if free_idx != move_idx
                        moves[free_idx] = move_idx
                        reverse[move_idx] = free_idx
                    end
                    move_idx += 1
                end
                free_idx += 1
            end
        end
        i += 1
    end
    return shuffle, moves
end

function diff(a::NodeVector, b::NodeVector, patches=Patch[])
    shuffle, moves = reorder(a, b)

    len_a = length(a)
    len_b = length(b)

    len = max(len_a, len_b)

    for i=1:len
        left = try a[i] catch nothing end
        right = get(shuffle, i, nothing)

        if left == nothing
            if right != nothing
                # Node inserted
                push!(patches, Insert(right))
            end
        elseif right == nothing
            if left != nothing
                # node removed
                push!(patches, Delete(right))
            end
        else
            d = diff(left, right)
            if d != nothing
                push!(patches, d)
            end
        end
    end
    if !isempty(moves)
        push!(patches, Reorder(a, moves))
    end
    patches
end

function diff(el::Elem, a::Attrs, b::Attrs)
    added = setdiff(b, a)
    deleted = setdiff(a, b)
    if length(added) != 0 || length(deleted) != 0
        return AttrDiff(el, added, deleted)
    end
end
