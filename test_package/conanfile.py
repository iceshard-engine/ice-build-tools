from conan import ConanFile, tools
from conan.tools.env import VirtualRunEnv

class IceBuildToolsTestsConan(ConanFile):
    settings = "os"

    def requirements(self):
        self.requires(self.tested_reference_str)

    def layout(self):
        self.folders.build = 'build'
        self.folders.generators = 'build/generators'

    def test(self):
        env = VirtualRunEnv(self)
        with env.vars().apply():
            if self.settings.os == "Windows":
                self.run("%MOON_SCRIPT% {}/test_app.moon hello".format(self.source_folder))

            if self.settings.os == "Linux":
                self.run("lua $MOON_SCRIPT {}/test_app.moon hello".format(self.source_folder))
