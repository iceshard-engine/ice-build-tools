
option = (tab) -> func:'option', args:{ tab.name, tab.description, tab.default, tab.convert, tab.args, nil }
flag = (tab) -> func:'flag', args:{ tab.name, tab.description, tab.default, tab.convert, nil, tab.count }

class Command
    new: (@parser) =>

        -- Add all defined arguments from the given class
        add_class_arguments = (clazz) ->
            return unless clazz.arguments

            for { :func, :args } in *clazz.arguments
                @parser[func] @parser, unpack args

        -- Iterate over the whole command inheritance
        current_clazz = @@
        while current_clazz ~= nil
            add_class_arguments current_clazz
            current_clazz = current_clazz.__parent

    execute: =>


{ :Command, option, flag }
