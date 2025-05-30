from conan import ConanFile
from conan.errors import ConanException
from shutil import copyfile, copytree
from conan.tools.scm import Git
from conan.tools.files import rmdir, copy, rename, replace_in_file
from conan.tools.env import VirtualBuildEnv, VirtualRunEnv
from os.path import join

import os
import json

class IceBuildToolsConan(ConanFile):
    name = "ice-build-tools"
    version = "1.10.4"
    user = "iceshard"
    channel = "stable"

    license = "MIT"
    description = "IceShard - build tools base"
    url = "https://github.com/iceshard-engine/ice-build-tools"

    settings = "os"
    requires = "moonscript-installer/0.5.0@iceshard/stable"

    exports_sources = [ "source/*", "scripts/*", "bootstrap/*", "LICENSE" ]

    options = {
        "template": [None, "ANY"],
        "template_repo": [None, "ANY"],
        "project_name": [None, "ANY"]
    }
    default_options = {
        "template": None,
        "template_repo": None,
        "project_name": None
    }

    def package_id(self):
        del self.info.settings.os
        del self.info.options.template
        del self.info.options.template_repo
        del self.info.options.project_name

    def deploy(self):
        # Access the project template that was provided as an option
        # we recover the saved url and commit from conandata.yml and use them to get sources
        template_settings = None
        if self.options.template != "None" and self.options.template_repo != "None":
            template_repo = str(self.options.template_repo)
            template_repo_path = "build/template_repo"

            # If we don't have a full URL we just check for github repos
            if template_repo.startswith("https://") == False:
                template_repo = "https://github.com/{}".format(template_repo)

            git = Git(self)
            git.clone(url=template_repo, target=template_repo_path, args=['--depth', '1'])

            # Check if tempalte file exists
            if os.path.exists("{}/{}.json".format(template_repo_path, self.options.template)):
                # Copy the main template file
                copy(self, "{}.json".format(self.options.template), src=template_repo_path, dst="tools")
                rename(self, "{}/{}.json".format("tools", self.options.template), "tools/template_settings.json")

                # Load the template file
                loaded_settings = tools.load("tools/template_settings.json")
                template_settings = json.loads(loaded_settings)

                # Copy the basic template structure
                if template_settings != None and template_settings.get('basic_layout') != None:
                    copy(self, "*", template_settings['basic_layout'], ".")

                # Remove the repo from the build folder (no longer needed)
                rmdir(self, template_repo_path)

            else:
                self.output.warning("Template '{}' not found in repository '{}'. Trying base package templates...".format(self.options.template, self.options.template_repo))

            # Remove the repo from the build folder (no longer needed)
            rmdir(self, template_repo_path)

        # Check if the template is part of the base package if we failed to find it in the repo
        if template_settings == None and self.options.template != "None":
            template_repo_path = "{}/bootstrap/templates".format(self.package_folder)

            if os.path.exists("{}/{}.json".format(template_repo_path, self.options.template)):
                # Copy the main template file
                copy(self, "{}.json".format(self.options.template), src=template_repo_path, dst="tools")
                rename(self, "{}/{}.json".format("tools", self.options.template), "tools/template_settings.json")

                # Load the template file
                loaded_settings = tools.load("tools/template_settings.json")
                template_settings = json.loads(loaded_settings)

                # Copy the basic template structure
                if template_settings != None and template_settings.get('basic_layout') != None:
                    copy(self, "*", src="{}/layouts/{}".format(template_repo_path, template_settings['basic_layout']), dst=".")

            else:
                raise ConanException("The given template '{}' does not exist. Exiting setup.".format(self.options.template))

        # Basic bootstrap files for IBT
        self.copy("*", src="bootstrap/shared", keep_path=True)
        self.copy("*", src="bootstrap/{}".format(str(self.settings.os).lower()), keep_path=True)
        self.copy("*", src="bootstrap/tools", dst="tools", keep_path=True)

        # Download extra files that are defined in this template
        if template_settings != None and template_settings.get('extra_files') != None:
            for extra_file in template_settings.get('extra_files'):
                tools.download(extra_file['url'], extra_file['destination'])

        # Generate the conanfile.txt used to boostrap a project
        with open("{}/tools/conanfile.txt".format(self.install_folder), 'w') as f:
            f.write("[requires]\n")
            f.write("{}/{}@{}/{}\n".format(self.name, self.version, self.user, self.channel))

            # Additional dependencies
            f.write("fastbuild-installer/1.08@iceshard/stable\n")
            # if template_settings != None and 'tools' in template_settings and 'dependencies' in template_settings.tools:
            #     for generator in template_settings.tools.dependencies:
            #         pass

            # Generators
            f.write("\n[generators]\n")
            f.write("virtualenv\n")
            if template_settings != None and template_settings.get('tools') != None and template_settings['tools'].get('generators') != None:
                for generator in template_settings['tools']['generators']:
                    f.write("{}\n".format(generator))

            f.close()

        # Rename / replace a few strings if project name is provided
        if self.options.project_name != "None":
            replace_in_file(self, 'workspace.moon', 'NewProject', str(self.options.project_name))

    def generate(self):
        pass

    def build(self):
        # Generate IBT moonscript file with IBT metadata
        ibt_path = "source/ibt"
        if os.path.exists(ibt_path) == False:
            os.mkdir(ibt_path)

        with open("source/ibt/ibt.moon", 'w') as f:
            f.write("IBT =\n")
            f.write("  version: '{}'\n".format(self.version))
            f.write("  conan:\n")
            f.write("    channel: '{}'\n".format(self.channel))
            f.write("    user: '{}'\n".format(self.user))
            f.write("    version: '{}'\n".format(self.version))
            f.write("  fbuild_scripts: os.getenv 'ICE_FBUILD_SCRIPTS'\n")
            f.write("  python_scripts: os.getenv 'ICE_PYTHON_SCRIPTS'\n")
            f.write("\n")
            f.write("{ :IBT }\n")
            f.close()

        # Copy the rxi/json to the scripts folder
        copy(self, "*.lua", src="source/rxi", dst="scripts/lua/rxi")

        renv = VirtualRunEnv(self)
        benv = VirtualBuildEnv(self)
        env = benv.environment()
        env.compose_env(renv.environment())

        with env.vars(self).apply():
            # Build all moonscript files directly into scripts
            if self.settings.os == "Windows":
                self.run("%MOONC_SCRIPT% source/ice -t scripts/lua")
                self.run("%MOONC_SCRIPT% source/ibt -t scripts/lua")
            if self.settings.os == "Linux":
                self.run("lua $MOONC_SCRIPT source/ice -t scripts/lua")
                self.run("lua $MOONC_SCRIPT source/ibt -t scripts/lua")

        # Prepare the directory for tools bootstrap file.
        tools_path = "bootstrap/tools"
        if os.path.exists(tools_path) == False:
            os.mkdir(tools_path)

        # Generate the conanfile.txt used to boostrap a project
        with open("{}/conanfile.txt".format(tools_path), 'w') as f:
            f.write("[requires]\n")
            f.write("{}/{}@{}/{}\n".format(self.name, self.version, self.user, self.channel))
            # Additional dependencies
            f.write("fastbuild-installer/1.10@iceshard/stable\n")

            f.write("\n[generators]\n")
            f.write("virtualenv\n")
            f.close()

    def package(self):
        copy(self, "LICENSE", src=self.source_folder, dst=self.package_folder, keep_path=False)
        copy(self, "*.*", src=join(self.build_folder, "scripts/"), dst=join(self.package_folder, "scripts/"), keep_path=True)
        copy(self, "*.*", src=join(self.build_folder, "bootstrap/"), dst=join(self.package_folder, "bootstrap/"), keep_path=True)

    def package_info(self):
        self.runenv_info.define("IBT_DATA", os.path.join(self.package_folder, "scripts/data"))
        self.runenv_info.append("LUA_PATH", os.path.join(self.package_folder, "scripts/lua/?.lua"), separator=';')
        self.runenv_info.append("LUA_PATH", os.path.join(self.package_folder, "scripts/lua/?/init.lua"), separator=';')

        self.runenv_info.define("ICE_BUILT_TOOLS_VER", self.version)
        self.runenv_info.define("ICE_FBUILD_SCRIPTS", os.path.join(self.package_folder, "scripts/fastbuild"))
        self.runenv_info.define("ICE_PYTHON_SCRIPTS", os.path.join(self.package_folder, "scripts/python"))
        if self.settings.os == "Windows":
            self.runenv_info.define("ICE_SCRIPT", os.path.join(self.package_folder, "scripts/shell/build_win.bat"))
        if self.settings.os == "Linux":
            self.runenv_info.define("ICE_SCRIPT", os.path.join(self.package_folder, "scripts/shell/build_linux.sh"))
