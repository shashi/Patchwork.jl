export diff

import Base.diff

@compat abstract type Patch end

immutable Insert <: Patch b end
immutable Overwrite{T <: Node} <: Patch b::T end
immutable Delete <: Patch end
immutable Reorder <: Patch moves::Dict end
immutable DictDiff <: Patch updates::Dict end

function key_idxs(ns)
    i = j = 1
    idxs = Dict()
    keys = Any[]
    for x in ns
        k = key(x)
        if k == nothing
            idxs[j] = i
            push!(keys, j)
            j += 1
        else
            idxs[k] = i
            push!(keys, k)
        end
        i += 1
    end
    idxs, keys
end

function diff!(a::AbstractVector, b::AbstractVector, index, patches; parentpatch=Patch[])
    if a === b return parentpatch end

    len_a = length(a)
    len_b = length(b)

    if len_a == 1 && len_b == 1
        diff!(a[1], b[1], index+1, patches)
        return parentpatch
    end

    a_key_idxs, a_keys = key_idxs(a)
    b_key_idxs, b_keys = key_idxs(b)

    ord = Dict()
    n = max(len_a, len_b)

    for i = 1:n
        index += 1
        if i <= len_a
            moved_to = get(b_key_idxs, a_keys[i], 0)
            if moved_to == 0
                patches[index] = Delete()
            else
                diff!(a[i], b[moved_to], index, patches)
                if i != moved_to
                    ord[i] = moved_to
                end
            end
            index += count(a[i])
        end
        if i <= len_b
            moved_from = get(a_key_idxs, b_keys[i], 0)
            if moved_from == 0
                # We don't need to save where this goes
                parentpatch = push!(parentpatch, Insert(b[i]))
            end
        end
    end
    if !isempty(ord)
        push!(parentpatch, Reorder(ord))
    end
end

diff!(a::TextNode, b::TextNode, index, patches) =
    a === b || a.text == b.text ?
        nothing :
        patches[index] = Patch[Overwrite(b)]

diff!(a::Elem, b::TextNode, index, patches) =
    patches[index] = Patch[Overwrite(b)]

diff!(a::TextNode, b::Elem, index, patches) =
    patches[index] = Patch[Overwrite(b)]

# If element's tag or ns is changed
diff!(a::Elem, b::Elem, index, patches) =
    patches[index] = Patch[Overwrite(b)]

function diff!{ns, tag}(a::Elem{ns, tag}, b::Elem{ns, tag}, index, patches)
    if a === b return patches end

    patch = get(patches, index, Patch[])

    proppatch = diff(properties(a), properties(b))
    if proppatch !== nothing
        patch = push!(patch, DictDiff(proppatch))
    end

    diff!(a.children, b.children, index, patches, parentpatch=patch)
    if !isempty(patch)
        patches[index] = patch
    end
end

are_equal(a::AbstractArray, b::AbstractArray) = a === b || a == b
are_equal(a::AbstractString, b::Symbol) = a == string(b)
are_equal(a::Symbol, b::AbstractString) = string(a) == b
are_equal(a, b) = a == b

function diff(a::Associative, b::Associative)
    if a === b return nothing end

    updates = Dict()
    for (k, v) in a
        if haskey(b, k)
            if !are_equal(v, b[k])
                if isa(b[k], Associative) || isa(b[k], PropHook)
                    dictdiff = diff(v, b[k])
                    if !is(dictdiff, nothing)
                        updates[k] = dictdiff
                    end
                else
                    updates[k] = b[k]
                end
            end
        else
            # deleted
            if isa(v, Associative)
                updates[k] = diff(v, Dict())
            elseif isa(v, PropHook)
                updates[k] = diff(v, PropHook("", nothing))
            else
                updates[k] = nothing
            end
        end
    end
    for (k, v) in b
        if haskey(a, k) continue end
        updates[k] = v
    end
    if isempty(updates)
        return nothing
    else
        return updates
    end
end

function diff(a::Node, b::Node)
    patches = Dict()
    diff!(a, b, 0, patches)
    return patches
end
