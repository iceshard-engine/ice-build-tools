from conans import ConanFile, MSBuild, tools
from conans.errors import ConanException
from shutil import copyfile, copytree
from conan.tools.scm import Git
from conan.tools.files import rmdir, copy, rename, replace_in_file

import os
import json

class IceBuildToolsConan(ConanFile):
    name = "ice-build-tools"
    version = "1.1.0"
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

    def build(self):
        # Generate IBT moonscript file with IBT metadata
        os.mkdir("source/ibt")
        with open("source/ibt/ibt.moon", 'w') as f:
            f.write("IBT =\n")
            f.write("  version: '{}'\n".format(self.version))
            f.write("  conan:\n")
            f.write("    channel: '{}'\n".format(self.channel))
            f.write("    user: '{}'\n".format(self.user))
            f.write("    version: '{}'\n".format(self.version))
            f.write("\n")
            f.write("{ :IBT }\n")
            f.close()

        # Build all moonscript files
        if self.settings.os == "Windows":
            self.run("%MOONC_SCRIPT% source/ice -t build")
            self.run("%MOONC_SCRIPT% source/ibt -t build")
        if self.settings.os == "Linux":
            self.run("lua $MOONC_SCRIPT source/ice -t build")
            self.run("lua $MOONC_SCRIPT source/ibt -t build")

        # Prepare the directory for tools bootstrap file.
        tools_path = "bootstrap/tools"
        if os.path.exists(tools_path) == False:
            os.mkdir(tools_path)

        # Generate the conanfile.txt used to boostrap a project
        with open("{}/conanfile.txt".format(tools_path), 'w') as f:
            f.write("[requires]\n")
            f.write("{}/{}@{}/{}\n".format(self.name, self.version, self.user, self.channel))
            # Additional dependencies
            f.write("fastbuild-installer/1.07@iceshard/stable\n")

            f.write("\n[generators]\n")
            f.write("virtualenv\n")
            f.close()

    def package(self):
        self.copy("LICENSE", src=".", dst=".", keep_path=False)
        self.copy("*.lua", src="build/", dst="scripts/lua/", keep_path=True)
        self.copy("*.*", src="scripts/", dst="scripts/", keep_path=True)
        self.copy("*.*", src="bootstrap/", dst="bootstrap/", keep_path=True)
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
