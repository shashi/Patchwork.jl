module.exports = nodeIndex

function nodeIndex(tree, indices, nodes) {
    if (!indices || indices.length === 0) {
        return {}
    } else {
        indices.sort(ascending)
        return recurse(tree, indices, nodes, 0)
    }
}

function recurse(tree, indices, nodes, rootIndex) {
    nodes = nodes || {}


    if (tree) {
        if (indexInRange(indices, rootIndex, rootIndex)) {
            nodes[rootIndex] = tree
        }

        var vChildren = tree.children

        if (vChildren) {

            for (var i = 0; i < vChildren.length; i++) {
                rootIndex += 1

                var vChild = vChildren[i]
                var nextIndex = rootIndex + (vChild.count || 0)

                // skip recursion down the tree if there are no nodes down here
                if (indexInRange(indices, rootIndex, nextIndex)) {
                    recurse(vChild, indices, nodes, rootIndex)
                }

                rootIndex = nextIndex
            }
        }
    } else {
        rootIndex
    }

    return nodes
}

// Binary search for an index in the interval [left, right]
function indexInRange(indices, left, right) {
    if (indices.length === 0) {
        return false
    }

    var minIndex = 0
    var maxIndex = indices.length - 1
    var currentIndex
    var currentItem

    while (minIndex <= maxIndex) {
        currentIndex = ((maxIndex + minIndex) / 2) >> 0
        currentItem = indices[currentIndex]

        if (minIndex === maxIndex) {
            return currentItem >= left && currentItem <= right
        } else if (currentItem < left) {
            minIndex = currentIndex + 1
        } else  if (currentItem > right) {
            maxIndex = currentIndex - 1
        } else {
            return true
        }
    }

    return false;
}

function ascending(a, b) {
    return a > b ? 1 : -1
}
