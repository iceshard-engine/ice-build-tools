from conans import ConanFile, MSBuild, tools
from shutil import copyfile, copytree
import os

class IceBuildToolsConan(ConanFile):
    name = "ice-build-tools"
    version = "0.1.2"
    license = "MIT"
    description = "IceShard - build tools base"
    url = "https://github.com/iceshard-engine/ice-build-tools"

    settings = "os"
    requires = "moonscript-installer/1.0.2@iceshard/stable"

    # Additional exports
    exports_sources = [ "source/*", "scripts/*", "LICENSE" ]

    def build(self):
        self.run("moonc source/ice -t build")

    def package(self):
        self.copy("LICENSE", src=".", dst=".", keep_path=False)
        self.copy("*.lua", src="build/", dst="scripts/lua/", keep_path=True)
        self.copy("*.*", src="scripts/shell/", dst="scripts/shell/", keep_path=False)
        self.copy("*.bff", src="scripts/fastbuild/", dst="scripts/fastbuild/", keep_path=True)

    def package_info(self):
        self.env_info.LUA_PATH.append(os.path.join(self.package_folder, "scripts/lua/?.lua"))
        self.env_info.LUA_PATH.append(os.path.join(self.package_folder, "scripts/lua/?/init.lua"))

        self.env_info.ICE_FBUILD_SCRIPTS = os.path.join(self.package_folder, "scripts/fastbuild")
        if self.settings.os == "Windows":
            self.env_info.ICE_SCRIPT = os.path.join(self.package_folder, "scripts/shell/build_win.bat")
        if self.settings.os == "Linux":
            self.env_info.ICE_SCRIPT = os.path.join(self.package_folder, "scripts/shell/build_linux.sh")
