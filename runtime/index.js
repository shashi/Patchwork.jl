var VNode = require('virtual-dom/vtree/vnode');
var VText = require('virtual-dom/vtree/vtext');
var VPatch = require('virtual-dom/vtree/vpatch');
var diff = require('virtual-dom/diff');
var patch = require('virtual-dom/patch');
var createElement = require('virtual-dom/create-element');
var nodeIndex = require('./node-index');
var patchVNode = require('./patch-vnode');
var isArray = require('x-is-array');

var P = Patchwork = {
    nodes: {},
    Node: function (id, jlNode) {
        el = document.getElementById(id)
        this.id = id
        if (jlNode) {
            // Note: makes this.root
            this.mount(Patchwork.makeVNode(jlNode), el)
        }
        P.nodes[id] = this
    },
    NAMESPACES: {
        "xhtml": null,
        "svg": "http://www.w3.org/2000/svg",
        null: null
    },
    refDiff: function (a, b, p) {
        var a = P.makeVNode(a)
            b = P.makeVNode(b)
            p = P.makeVPatches(a, p)
        console.log(p, diff(a, b));
    },
    makeVNode: function (jlNode) {
        if ('text' in jlNode) return new VText(jlNode.text);
        return new VNode(jlNode.tagName, jlNode.properties,
                         _.map(jlNode.children, Patchwork.makeVNode),
                         jlNode.key, Patchwork.NAMESPACES[jlNode.namespace]);
    },
    makeVPatches: function (root, jlPatches) {
        var indices = [];
        var vpatches = {a: root}
        for (var idx in jlPatches) {
            indices.push(Number(idx))
        }
        nodes = nodeIndex(root, indices)

        for (var idx in jlPatches) {
            vpatches[idx] = P.makeVPatch(nodes[idx], jlPatches[idx]);
        }
        return vpatches
    },
    makeVPatch: function (vnode, jlPatch) {
        if (isArray(jlPatch)) {
            // multiple patches to the same VNode
            var ps = [];
            for (var i=0, l=jlPatch.length; i < l; i++) {
                ps[i] = P.makeVPatch(vnode, jlPatch[i])
            }
            return ps
        }

        var type, patch;
        for (var k in jlPatch) {
            type = k;
            patch = jlPatch[k];
            break; // inorite?
        }

        function vpatch(p) { return new VPatch(type, vnode, p); }

        switch (Number(type)) {
        case VPatch.VTEXT:
            return vpatch(new VText(patch));
        case VPatch.VNODE:
            return vpatch(P.makeVNode(patch));
        case VPatch.PROPS:
            return vpatch(patch);
        case VPatch.ORDER:
            return vpatch(patch);
        case VPatch.INSERT:
            return vpatch(P.makeVNode(patch)); // What about vtext?
        case VPatch.REMOVE:
            return vpatch(null);
        default:
            return null;
        }
    }
}

Patchwork.Node.prototype = {
    mount: function (vnode, outer) {
        var el = createElement(vnode);
        outer.appendChild(el)
        this.element = el
        this.root = vnode;
        return el;
    },
    patch: function (vpatches) {
        // apply patch to DOM nodes
        this.element = patch(this.element, vpatches)
        this.root = patchVNode(this.root, vpatches)
    }
}


// IJulia setup
if (jQuery) {
    $(document).ready(function () {
        if (IPython) {
            var commMgr =  IPython.notebook.kernel.comm_manager;
            commMgr.register_target("PatchStream", function (comm, msg) {
                var nodeId = msg.content.data.pwid;
                comm.on_msg(function (msg) {
                    var node = P.nodes[nodeId],
                        raw = msg.content.data,
                        vpatches = P.makeVPatches(node.root, raw)
                    node.patch(vpatches)
                });
            });
        }
    });
}

window.Patchwork = Patchwork;
