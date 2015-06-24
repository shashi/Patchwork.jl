var isWidget = require("vtree/is-widget")
var isVText = require("vtree/is-vtext")
var VPatch = require("vtree/vpatch")
var patchUtil = require("./patch-util.js")

module.exports = applyPatch

function applyPatch(type, vNode, patch) {

    switch (type) {
        case VPatch.REMOVE:
            return removeNode(vNode)
        case VPatch.INSERT:
            return insertNode(vNode, patch)
        case VPatch.VTEXT:
            return stringPatch(vNode, patch)
        case VPatch.VNODE:
            return vNodePatch(vNode, patch)
        case VPatch.ORDER:
            patchUtil.reorder(vNode.children, patch)
            return vNode
        case VPatch.PROPS:
            patchUtil.patchObject(vNode.properties, patch)
            return vNode
        default:
            return vNode
    }
}

function offsetCount(node, count) {
    if (!node) { return }
    if (node.count !== undefined) {
        node.count = node.count + count
        offsetCount(node.up, count)
    } else {
        node.count = count
    }
}

function removeNode(node) {
    if (!node) { return }
    var count = node.count,
        up = node.up

    var idx = up.children.indexOf(node)
    if (idx > -1) {
        up.children.splice(idx, 1)
        var count = 0
        if (isVText(node)) {
            count = -1
        } else {
            count = -node.count - 1
        }
        offsetCount(up, count)
    }
    delete node

    return null
}

function insertNode(node, child) {
    node.children.push(child)
    var count = 0
    if (isVText(child)) {
        count = 1
    } else {
        count = child.count + 1
    }
    offsetCount(node, count)
    child.up = node
    return node
}

function stringPatch(node, patch) {
    node.text = patch.text
    return node
}

function vNodePatch(node, patch) {
    var up = node.up
    if (!up) {
        // copy over the patch to the root node
        for (key in patch) {
            if (!patch.hasOwnProperty(key)) continue
            node[key] = patch[key]
        }
        return
    }
    var idx = up.children.indexOf(node),
        count = patch.count || 0

    if (idx > -1) {
        up.children[idx] = patch
        if (node.count != count) {
            offsetCount(up, count - node.count)
        }
    }

    return node
}
