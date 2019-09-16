from conans import ConanFile, MSBuild, tools
from shutil import copyfile
import os

class IceBuildToolsConan(ConanFile):
    name = "ice-build-tools"
    version = "0.0.1"
    license = "MIT"
    description = "IceShard - build tools base"
    url = "https://github.com/iceshard-engine/ice-build-tools"

    generators = [ "premake" ]

    requires = "moonscript-installer/0.5.0@iceshard/stable"

    # Additional exports
    exports_sources = [ "source/*" ]

    # Get the sources from lua.org
    def source(self):
        pass

    # Export the files available in the package
    def package(self):
        # self.copy("LICENSE", src=self.MOONSCRIPT_FOLDER_NAME, dst="LICENSE_MOONSCRIPT")
        self.copy("LICENSE", src=".")

        # # Additonal batch files to copy
        # self.copy("*.bat", src="bin", dst="scripts/moonscript/bin", keep_path=False)

        # # Lua and Moonscript files
        self.copy("*.moon", src="source/", dst="scripts/", keep_path=True)
        # self.copy("*.lua", src=self.ARGPARSE_FOLDER_NAME, dst="scripts/argparse", keep_path=False)
        # self.copy("bin/*", src=self.MOONSCRIPT_FOLDER_NAME, dst="scripts/moonscript", keep_path=True)
        # self.copy("moon/*", src=self.MOONSCRIPT_FOLDER_NAME, dst="scripts/moonscript", keep_path=True)
        # self.copy("moonscript/*", src=self.MOONSCRIPT_FOLDER_NAME, dst="scripts/moonscript", keep_path=True)


    def package_info(self):
        # Moonscript paths info
        self.env_info.MOON_PATH.append(os.path.join(self.package_folder, "source?.moon"))
        self.env_info.MOON_PATH.append(os.path.join(self.package_folder, "?\\init.moon"))
