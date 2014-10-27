var isWidget = require("virtual-dom/vtree/is-widget")
var VPatch = require("virtual-dom/vtree/vpatch")
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
        offsetCount(up, -node.count - 1)
    }
    delete node

    return null
}

function insertNode(node, child) {
    node.children.push(child)
    offsetCount(node, child.count + 1)
    child.up = node
    return node
}

function stringPatch(node, patch) {
    node.text = patch.text
    return node
}

function vNodePatch(node, patch) {
    var up = node.up,
        idx = up.children.indexOf(node),
        count = patch.count || 0

    if (idx > -1) {
        up.children[idx] = patch
        if (node.count != count) {
            offsetCount(up, count - node.count)
        }
    }

    return node
}
