
import Log from require "ice.core.logger"

class Locator
    @Type: class
        @Toolchain: 'Toolchain'
        @PlatformSDK: 'Platform SDK'
        @CommonSDK: 'Common SDK'

    new: (@type, @name, @id) =>

    add_result: (object, type=@type) =>
        if type == Locator.Type.Toolchain
            table.insert @context.toolchains, object
        elseif type == Locator.Type.PlatformSDK
            table.insert @context.platform_sdks, object
        elseif type == Locator.Type.CommonSDK
            table.insert @context.additional_sdks, object
        else
            Log\error "Unknown result type '#{@type}' encountered while executing '#{type}' (#{@name}) locator"

    install_internal: =>
        @\install! if (type @.install) == 'function'

    locate_internal: (@context) =>
        @\locate @context

        -- Remove context info after we finished
        @context = nil


{ :Locator }
