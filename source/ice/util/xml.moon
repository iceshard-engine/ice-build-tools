import Log from require "ice.core.logger"

xml2lua = require "xml2lua.xml2lua"
domhandler = require "xml2lua.xmlhandler.dom"
treehandler = require "xml2lua.xmlhandler.tree"

_find_existing_xml_node = (dom, path, filter) ->
    return if dom == nil or (dom._type ~= 'ELEMENT' and dom._type ~= 'ROOT')
    return dom if dom._name == path
    return if dom._children == nil or #dom._children == 0

    children = { dom }
    for subnode in path\gmatch "([^%.]+)"

        -- Find the next child element
        candidate = nil
        for subdom in *children
            if subdom._name == subnode and filter subdom
                candidate = subdom
                break

        -- Unless the have a valid candidate we create a new one
        if candidate
            children = candidate._children
            dom = candidate
        else
            dom = nil
            break

    return dom

_get_or_create_xml_node = (dom, path, filter) ->
    return if dom == nil or (dom._type ~= 'ELEMENT' and dom._type ~= 'ROOT')
    return dom if dom._name == path
    return if dom._children == nil

    children = { dom }
    for subnode in path\gmatch "([^%.]+)"

        -- Find the next child element
        candidate = nil
        for subdom in *children
            if subdom._name == subnode and filter subdom
                candidate = subdom
                break

        -- Unless the have a valid candidate we create a new one
        unless candidate
            candidate = _type:'ELEMENT', _name:subnode, _children:{}
            table.insert dom._children, candidate
            children = candidate._children
            dom = candidate

        else
            children = candidate._children
            dom = candidate

    return dom

class XMLNode
    new: (@dom) =>

    find: (key, opts = {}) =>
        _find_existing_xml_node @dom, key, (opts.filter or -> true)

    get: (key, opts = {}) =>
        _get_or_create_xml_node @dom, key, (opts.filter or -> true)

    @element = (name, attribs) =>
        _type: 'ELEMENT', _name:name, _attr:attribs, _children:{}

class XML
    @decl = (attribs) =>
        _type: 'DECL', _name:'xml', _attr:attribs or {version:"1.0", encoding:"UTF-8"}

    @encode = (object, opts = { simplified:false, decl:XML\decl! }) =>
        xml2lua.printable(object) if opts.debug_print

        unless simplified
            handler = domhandler\new!

            children = {}
            table.insert children, opts.decl if opts.decl and opts.decl._type == 'DECL'
            table.insert children, object

            handler\toXml _children:children, _type: "ROOT"

        else
            xml2lua.toXml object, "root"

    @decode = (xmldoc, opts = { simplified:false }) =>
        handler = domhandler\new!
        if simplified
            handler = treehandler\new!

        parser = xml2lua.parser handler
        Log\debug "Parsing XML document '#{type xmldoc}' with parser '#{type parser}'"
        parser\parse xmldoc
        Log\debug "Parsing: #{handler.root ~= nil and 'Ok' or 'Error'}"
        handler.root

{ :XML, :XMLNode }
