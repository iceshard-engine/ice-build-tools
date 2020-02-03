from conans import ConanFile, tools
import os

class IceBuildToolsTestsConan(ConanFile):
    def build(self):
        pass

    def test(self):
        self.run("{} {}/test_app.moon hello".format(tools.get_env("ICE_SCRIPT"), self.source_folder))
