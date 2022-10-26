import Command, argument, option, flag from require "ice.command"

class BaseCommand extends Command
    @arguments { }

    prepare: (args, project) =>
    execute: (args) =>

{ :BaseCommand, :argument, :option, :flag }
