require "yaml"

module MCollective
  module PluginPackager
    class ForgePackager
      def initialize(plugin, pluginpath=nil, signature=nil, verbose=false, keep_artifacts=nil, module_template=nil)
        @plugin = plugin
        @verbose = verbose
        @keep_artifacts = keep_artifacts
        @module_template = module_template || File.join(File.dirname(__FILE__), "templates", "forge")
      end

      def which(cmd)
        exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
        ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable?(exe) && !File.directory?(exe)
          end
        end
        nil
      end

      def create_packages
        assert_new_enough_pdk
        validate_environment

        begin
          puts("Building Choria module %s" % module_name)

          @tmpdir = Dir.mktmpdir("mcollective_packager")

          make_module_dirs
          copy_module_files
          generate_agent_json_ddls
          render_templates
          copy_additional_files
          run_build
          move_package

          puts("Completed building module for %s" % module_name)
        rescue
          warn("Failed to build plugin module: %s: %s" % [$!.class, $!.to_s])
        ensure
          if @keep_artifacts
            puts("Keeping build artifacts")
            puts("Build artifacts saved in %s" % @tmpdir)
          else
            cleanup_tmpdirs
          end
        end
      end

      def version
        if Integer(@plugin.revision) > 1
          "%s-%s" % [@plugin.metadata[:version], @plugin.revision]
        else
          @plugin.metadata[:version]
        end
      end

      def module_name
        "mcollective_%s_%s" % [
          @plugin.plugintype.downcase,
          @plugin.metadata[:name].downcase.gsub("-", "_")
        ]
      end

      def module_file_name
        "%s-%s-%s.tar.gz" % [@plugin.vendor, module_name, version]
      end

      def dirlist(type)
        @plugin.packagedata[type][:files].map do |file|
          file.gsub(/^\.\//, "") if File.directory?(file)
        end.compact
      rescue
        []
      end

      def filelist(type)
        @plugin.packagedata[type][:files].map do |file|
          file.gsub(/^\.\//, "") unless File.directory?(file)
        end.compact.uniq
      rescue
        []
      end

      def executablelist(type)
        @plugin.packagedata[type][:executable_files].map do |file|
          file.gsub(/^\.\//, "") unless File.directory?(file)
        end.compact.uniq
      rescue
        []
      end

      def hierakey(var)
        "%s::%s" % [module_name, var]
      end

      def module_override_data
        YAML.safe_load(File.read(".plugin.yaml"))
      rescue
        {}
      end

      def plugin_hiera_data
        {
          hierakey(:config_name) => @plugin.metadata[:name].downcase,
          hierakey(:common_files) => filelist(:common),
          hierakey(:executable_files) => executablelist(:agent),
          hierakey(:common_directories) => dirlist(:common),
          hierakey(:server_files) => filelist(:agent),
          hierakey(:server_directories) => dirlist(:agent),
          hierakey(:client_files) => filelist(:client),
          hierakey(:client_directories) => dirlist(:client)
        }.merge(module_override_data)
      end

      def make_module_dirs
        ["data", "manifests", "files/mcollective"].each do |dir|
          FileUtils.mkdir_p(File.join(@tmpdir, dir))
        end
      end

      def copy_additional_files
        if File.exist?("puppet")
          Dir.glob("puppet/*").each do |file|
            FileUtils.cp_r(file, @tmpdir)
          end
        end
      end

      def copy_module_files
        @plugin.packagedata.each_value do |data|
          data[:files].each do |file|
            clean_dest_file = file.gsub("./lib/mcollective", "")
            dest_dir = File.expand_path(File.join(@tmpdir, "files", "mcollective", File.dirname(clean_dest_file)))

            FileUtils.mkdir_p(dest_dir) unless File.directory?(dest_dir)
            FileUtils.cp(file, dest_dir) if File.file?(file)
          end
        end
      end

      def generate_agent_json_ddls
        agent_dir = File.expand_path(File.join(@tmpdir, "files", "mcollective", "agent"))

        if File.directory?(agent_dir)
          Dir.glob(File.join(agent_dir, "*.ddl")) do |file|
            agent_name = File.basename(file, ".ddl")
            json_file = File.join(agent_dir, "%s.json" % agent_name)

            if File.exist?(json_file)
              Log.warn("JSON DDL %s already exist, not regenerating from the %s" % [json_file, agent_name])
              next
            end

            ddl = DDL.new(agent_name, :agent, false)
            ddl.instance_eval(File.read(file))

            data = {
              "$schema" => "https://choria.io/schemas/mcorpc/ddl/v1/agent.json",
              "metadata" => ddl.meta,
              "actions" => []
            }

            ddl.actions.sort.each do |action|
              data["actions"] << ddl.action_interface(action)
            end

            File.open(json_file, "w") do |jddl|
              jddl.print(JSON.pretty_generate(data))
            end

            @plugin.packagedata[:common][:files] << "agent/%s.json" % agent_name
          end
        end
      end

      def render_templates
        templates = Dir.chdir(@module_template) do |_path|
          Dir.glob("**/*.erb")
        end

        templates.each do |template|
          infile = File.join(@module_template, template)
          outfile = File.join(@tmpdir, template.gsub(/\.erb$/, ""))
          render_template(infile, outfile)
        end
      end

      def render_template(infile, outfile)
        erb = ERB.new(File.read(infile), :safe_level => 0, :trim_mode => "-")
        File.open(outfile, "w") do |f|
          f.puts erb.result(binding)
        end
      rescue
        warn("Could not render template %s to %s" % [infile, outfile])
        raise
      end

      def validate_environment
        raise("Supplying a vendor is required, please use --vendor") if @plugin.vendor == "Puppet Labs"
        raise("Vendor names may not have a space in them, please specify a valid vendor using --vendor") if @plugin.vendor.include?(" ")
      end

      def pdk_path
        pdk_bin = which("pdk")
        pdk_bin ||= "/opt/puppetlabs/pdk/bin/pdk"

        pdk_bin
      end

      def assert_new_enough_pdk
        s = Shell.new("#{pdk_path} --version")
        s.runcommand
        actual_version = s.stdout.chomp
        required_version = "1.12.0"

        raise("Cannot build package. pdk #{required_version} or greater required.  We have #{actual_version}.") if Util.versioncmp(actual_version, required_version) < 0
      end

      def run_build
        PluginPackager.execute_verbosely(@verbose) do
          Dir.chdir(@tmpdir) do
            PluginPackager.safe_system("#{pdk_path} build --force")
          end
        end
      rescue
        warn("Build process has failed")
        raise
      end

      def move_package
        package_file = File.join(@tmpdir, "pkg", module_file_name)
        FileUtils.cp(package_file, ".")
      rescue
        warn("Could not copy package to working directory")
        raise
      end

      def cleanup_tmpdirs
        FileUtils.rm_r(@tmpdir) if File.directory?(@tmpdir)
      rescue
        warn("Could not remove temporary build directory %s" % [@tmpdir])
        raise
      end
    end
  end
end
