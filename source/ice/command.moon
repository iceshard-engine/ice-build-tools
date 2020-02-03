
option = (tab) -> func:'option', args:tab
flag = (tab) -> func:'flag', args:tab

class Command
    new: (@parser) =>

        -- Add all defined arguments from the given class
        add_class_arguments = (clazz) ->
            return unless clazz.arguments

            for { :func, :args } in *clazz.arguments
                @parser[func] @parser, args

        -- Iterate over the whole command inheritance
        current_clazz = @@
        while current_clazz ~= nil
            add_class_arguments current_clazz
            current_clazz = current_clazz.__parent

    execute: => true


{ :Command, :option, :flag }
