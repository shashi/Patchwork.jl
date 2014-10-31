var VNode = require('vtree/vnode');
var svg = require('virtual-hyperscript/svg');
var VText = require('vtree/vtext');
var VPatch = require('vtree/vpatch');
var diff = require('virtual-dom/diff');
var patch = require('virtual-dom/patch');
var createElement = require('virtual-dom/create-element');
var nodeIndex = require('./node-index');
var patchVNode = require('./patch-vnode');
var isArray = require('x-is-array');
var isVPatch = require('./is-vpatch');

var P = Patchwork = {
    nodes: {},
    debug: false,
    Node: function (id, jlNode) {
        el = document.getElementById(id)
        this.id = id
        if (jlNode) {
            // Note: makes this.root
            var vnode = Patchwork.makeVNode(jlNode)
            P.log("makeVNode: ", jlNode, "=>", vnode)
            this.mount(vnode, el)
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
        if (jlNode.namespace === "svg") {
            return svg(jlNode.tagName, jlNode.properties,
                         _.map(jlNode.children, Patchwork.makeVNode))
        } else {
            var key = null
            if (jlNode.properties && jlNode.properties.key) {
                key = jlNode.properties.key
                delete jlNode.properties.key
            }
            return new VNode(jlNode.tagName, jlNode.properties,
                             _.map(jlNode.children, Patchwork.makeVNode),
                             key, Patchwork.NAMESPACES[jlNode.namespace]);
        }
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
            if (vnode.namespace === P.NAMESPACES["svg"]) {
                patch = svg('dummy', patch, []).properties
            }
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
    },
    log: function () {
        if (console && P.debug) {
            console.log.apply(console, arguments);
        }
    }
}

Patchwork.Node.prototype = {
    mount: function (vnode, outer) {
        var el = createElement(vnode);
        P.log("createElement: ", vnode, "=>", el)
        outer.appendChild(el)
        this.element = el
        this.root = vnode;
        return el;
    },
    applyPatch: function (vpatches) {
        // apply patch to DOM nodes
        if (!isVPatch(vpatches)) {
            vpatches = P.makeVPatches(this.root, vpatches)
        }
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
                        patches = msg.content.data
                    node.applyPatch(patches)
                    P.log("received patches", patches)
                });
            });
        }
    });
}

window.Patchwork = Patchwork;
