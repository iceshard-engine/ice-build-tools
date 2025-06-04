import Validation from require "ice.core.validation"
import Locator from require "ice.locator"

sdks_list = { }

class SDKList
    @add = (locator) =>
        if Validation\ensure (locator.type == Locator.Type.PlatformSDK or locator.type == Locator.Type.CommonSDK), "Locator '#{locator.name}' is not a valid SDK locator. (type: #{locator.type})"
            table.insert sdks_list, locator

    @each = (fn) =>
        fn sdk for sdk in *sdks_list

{ :SDKList }
