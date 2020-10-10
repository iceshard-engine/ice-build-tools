from conans import ConanFile, tools
import os

class IceBuildToolsTestsConan(ConanFile):
    settings = "os"

    def build(self):
        pass

    def test(self):
        if self.settings.os == "Windows":
            self.run("{} {}/test_app.moon hello".format(tools.get_env("MOON_SCRIPT"), self.source_folder))

        if self.settings.os == "Linux":
            self.run("lua {} {}/test_app.moon hello".format(tools.get_env("MOON_SCRIPT"), self.source_folder))
