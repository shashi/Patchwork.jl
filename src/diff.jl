export diff

abstract Patch

type Insert <: Patch
    b
end

type Overwrite <: Patch
    b
end

type Delete <: Patch end

type Reorder <: Patch
    moves
end

type DictDiff <: Patch
    updated
    deleted
end

function key_idxs(ns; keyfn=key)
    i = 1
    idxs = Dict()
    for x in ns
        k = keyfn(x)
        if keyfn(x) != nothing
            idxs[k] = i
        else
            idxs[i] = i
        end
        i += 1
    end
    idxs
end

function diff!(a::AbstractVector, b::AbstractVector, index, patches; parentpatch=Patch[], keyfn=key)
    if a === b return parentpatch end

    len_a = length(a)
    len_b = length(b)

    if len_a == 1 && len_b == 1
        diff!(a[1], b[1], index+1, patches)
        return parentpatch
    end

    a_key_idxs = key_idxs(a)
    b_key_idxs = key_idxs(b)

    ord = Dict()
    n = max(len_a, len_b)

    index += 1
    for i = 1:n
        if i <= len_a
            moved_to = get(b_key_idxs, keyfn(a[i]), 0)
            if moved_to == 0
                patches[index] = Delete()
            else
                diff!(a[i], b[moved_to], index, patches)
                if i != moved_to
                    ord[i] = moved_to
                end
            end
        end
        if i <= len_b
            moved_from = get(a_key_idxs, keyfn(b[i]), 0)
            if moved_from == 0
                # We don't need to save where this goes
                parentpatch = push!(parentpatch, Insert(b[i]))
            end
        end
        if i <= len_a
            index += count(a[i])
        end
    end
    if !isempty(ord)
        push!(parentpatch, Reorder(ord))
    end
end

diff!(a::Text, b::Text, index, patches) =
    a === b || a.text == b.text ?
        nothing :
        patches[index] = Overwrite(b)

diff!(a::Elem, b::Text, index, patches) =
    patches[index] = Overwrite(b)

diff!(a::Text, b::Elem, index, patches) =
    patches[index] = Overwrite(b)

# If element's tag or ns is changed
diff!(a::Elem, b::Elem, index, patches) =
    patches[index] = Overwrite(b)

function diff!{ns, tag}(a::Elem{ns, tag}, b::Elem{ns, tag}, index, patches)
    if a === b return patches end

    patch = get(patches, index, Patch[])

    attrpatch = diff(a.attributes, b.attributes)
    if !is(attrpatch, nothing)
        patch = push!(patch, attrpatch)
    end

    diff!(a.children, b.children, index, patches, parentpatch=patch)
    if !isempty(patch)
        patches[index] = patch
    end
end

function diff(a::Associative, b::Associative)
    if a === b return nothing end

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
        push!(updated, (k, v))
    end
    if isempty(updated) && isempty(updated) && isempty(deleted)
        return nothing
    else
        DictDiff(updated, deleted)
    end
end

function diff(a::Node, b::Node)
    patches = Dict()
    diff!(a, b, 0, patches)
    return patches
end

