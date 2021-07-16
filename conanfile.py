from conans import ConanFile, MSBuild, tools
from shutil import copyfile, copytree
import os

class IceBuildToolsConan(ConanFile):
    name = "ice-build-tools"
    version = "0.4.5"
    license = "MIT"
    description = "IceShard - build tools base"
    url = "https://github.com/iceshard-engine/ice-build-tools"

    settings = "os"
    requires = "moonscript-installer/0.5.0@iceshard/stable"

    # Additional exports
    exports_sources = [ "source/*", "scripts/*", "LICENSE" ]

    def package_id(self):
        del self.info.settings.os

    def build(self):
        if self.settings.os == "Windows":
            self.run("%MOONC_SCRIPT% source/ice -t build")
        if self.settings.os == "Linux":
            self.run("lua $MOONC_SCRIPT source/ice -t build")

    def package(self):
        self.copy("LICENSE", src=".", dst=".", keep_path=False)
        self.copy("*.lua", src="build/", dst="scripts/lua/", keep_path=True)
        self.copy("*.*", src="scripts/shell/", dst="scripts/shell/", keep_path=False)
        self.copy("*.bff", src="scripts/fastbuild/", dst="scripts/fastbuild/", keep_path=True)

    def package_info(self):
        self.env_info.LUA_PATH.append(os.path.join(self.package_folder, "scripts/lua/?.lua"))
        self.env_info.LUA_PATH.append(os.path.join(self.package_folder, "scripts/lua/?/init.lua"))

        self.env_info.ICE_BUILT_TOOLS_VER = self.version
        self.env_info.ICE_FBUILD_SCRIPTS = os.path.join(self.package_folder, "scripts/fastbuild")
        if self.settings.os == "Windows":
            self.env_info.ICE_SCRIPT = os.path.join(self.package_folder, "scripts/shell/build_win.bat")
        if self.settings.os == "Linux":
            self.env_info.ICE_SCRIPT = os.path.join(self.package_folder, "scripts/shell/build_linux.sh")
