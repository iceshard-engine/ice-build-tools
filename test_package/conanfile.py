from conans import ConanFile, tools
import os

class IceBuildToolsTestsConan(ConanFile):
    def build(self):
        pass

    def test(self):
        self.run("lua {} {}/test_app.moon hello".format(tools.get_env("MOON_SCRIPT"), self.source_folder))
