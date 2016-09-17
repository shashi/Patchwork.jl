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
    Node: function (id, jlNode, el, renderOpts) {
        if (typeof(el) === "undefined") {
            el = document.getElementById(id)
        }
        this.id = id
        this.renderOptions = renderOpts
        if (jlNode) {
            // Note: makes this.root
            var vnode = P.makeVNode(jlNode)
            P.log("makeVNode: ", jlNode, "=>", vnode)
            this.mount(vnode, el, renderOpts)
        }
        P.nodes[id] = this
    },
    NAMESPACES: {
        "xhtml": null,
        "svg": "http://www.w3.org/2000/svg",
        null: null,
        undefined: null
    },
    refDiff: function (a, b, p) {
        var a = P.makeVNode(a)
            b = P.makeVNode(b)
            p = P.makeVPatches(a, p)
        console.log(p, diff(a, b));
    },
    massageProps: function (props) {
        if ("attributes" in props) {
            // we can't send undefined over JSON, so we turn nulls into undefs
            // so that VDom calls removeAttribute on the DOM node.
            //console.log("attributes ", props.attributes)
            for (var attr in props.attributes) {
                if (!props.attributes.hasOwnProperty(attr)) {
                    continue
                }
                if (props.attributes[attr] === null) {
                //console.log("remove ", attr, props.attributes[attr]);
                    props.attributes[attr] = undefined
                }
            }
        }
        return P.setupHooks(props);
    },
    hooks: {},
    register_hook: function (hook, f) {
        P.hooks[hook] = f;
    },
    setupHooks: function (props) {
        if (typeof props !== "object" || props == null) {
            return props;
        } else if (props && "_hook" in props) {
            if (props._hook in P.hooks) {
                v = P.hooks[props._hook](P.setupHooks(props.val));
                return v
            } else {
                console.warn("Unknown hook " + props._hook + "use Patchwork.register_hook to set it up")
                return undefined
            }
        } else {
            for (var k in props) {
                props[k] = P.setupHooks(props[k]);
            }
            return props;
        }
    },
    makeVNode: function (jlNode) {
        if ('txt' in jlNode) return new VText(jlNode.txt);
        var children = [],
            props = P.massageProps(jlNode.p || {})

        if (jlNode.c) {
            for (var i = 0, l = jlNode.c.length; i < l; i++) {
                children[i] = P.makeVNode(jlNode.c[i])
            }
        }

        if (jlNode.n === "svg") {
            return svg(jlNode.t, props, children)
        } else {
            var key = null
            if (props && props.key) {
                key = props.key
                delete props.key
            }
            return new VNode(jlNode.t,
                             props,
                             children,
                             key,
                             P.NAMESPACES[jlNode.n]);
        }
    },
    makeVPatches: function (root, jlPatches) {
        var indices = [];
        var vpatches = {a: root}
        for (var idx in jlPatches) {
            if (!jlPatches.hasOwnProperty(idx)) {
                continue
            }
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
            patch = P.massageProps(patch)
            if (vnode.namespace === P.NAMESPACES["svg"]) {
                patch = svg('dummy', patch, []).properties
            }
            return vpatch(patch);
        case VPatch.ORDER:
            return vpatch(patch);
        case VPatch.INSERT:
            return vpatch(P.makeVNode(patch));
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
    mount: function (vnode, outer, renderOpts) {
        var el = createElement(vnode, renderOpts);
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
        this.element = patch(this.element, vpatches, this.renderOptions)
        this.root = patchVNode(this.root, vpatches)
    }
}

function init(nb, cue) {
    if (!Patchwork.inited) {
        try {
            console.log("attempting Patchwork setup, cue:", cue)
            var commMgr =  nb.kernel.comm_manager;
            commMgr.register_target("PatchStream", function (comm, msg) {
                var nodeId = msg.content.data.pwid;
                comm.on_msg(function (msg) {
                    var node = P.nodes[nodeId],
                        patches = msg.content.data
                    node.applyPatch(patches)
                    P.log("received patches", patches)
                });
            });
            Patchwork.inited = true;
        } catch (e) {
            Patchwork.inited = false;
            console.log("ERROR initializing patchwork: ", e);
            console.log("attempting failed, cue:", cue)
        }
    }
}

// IJulia setup
if (typeof(window.IPython) !== "undefined") {
    init(IPython.notebook, "immediate");
    $(document).ready(function () { init(IPython.notebook, "document ready"); });
    $([IPython.events]).on("kernel_ready.Kernel kernel_created.Kernel", function (evt, nb) {
        init(nb, "kernel start")
    })
}

window.Patchwork = Patchwork;
