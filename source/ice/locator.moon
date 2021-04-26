
class Locator
    @Type: class
        @Toolchain: 'Toolchain'
        @PlatformSDK: 'Platform SDK'
        @CommonSDK: 'Common SDK'

    new: (@type, @name) =>
    locate: => false

{ :Locator }
