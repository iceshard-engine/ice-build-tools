import Command, argument, option, flag from require "ice.command"

class BaseCommand extends Command
    @settings { }
    @arguments { }

    init: (command) =>
    prepare: (args, project) =>
    execute: (args, project) =>

{ :BaseCommand, :argument, :option, :flag }
