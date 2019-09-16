from conans import ConanFile, MSBuild, tools
from shutil import copyfile, copytree
import os

class IceBuildToolsConan(ConanFile):
    name = "ice-build-tools"
    version = "0.0.1"
    license = "MIT"
    description = "IceShard - build tools base"
    url = "https://github.com/iceshard-engine/ice-build-tools"

    requires = "moonscript-installer/0.5.0@iceshard/stable"

    # Additional exports
    exports_sources = [ "source/*", "LICENSE" ]

    def build(self):
        self.run("moonc source/ice -t build")

    def package(self):
        self.copy("LICENSE", src=".", dst=".", keep_path=False)
        self.copy("*.lua", src="build/", dst="scripts/", keep_path=True)

    def package_info(self):
        self.env_info.LUA_PATH.append(os.path.join(self.package_folder, "scripts/?.lua"))
        self.env_info.LUA_PATH.append(os.path.join(self.package_folder, "scripts/?/init.lua"))
