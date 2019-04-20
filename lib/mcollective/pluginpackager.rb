module MCollective
  module PluginPackager

    class GenerateJsonDirNotFoundError < EncodingError
    end
    # Plugin definition classes
    require "mcollective/pluginpackager/agent_definition"
    require "mcollective/pluginpackager/standard_definition"

    # Package implementation plugins
    def self.load_packagers
      PluginManager.find_and_load("pluginpackager")
    end

    def self.[](klass)
      const_get(klass.to_s)
    end

    def self.generate_agent_json_ddls(plugin, tmpdir)
      agent_dir = File.expand_path(File.join(tmpdir, "agent"))

      if File.directory?(agent_dir)
        Dir.glob(File.join(agent_dir, "*.ddl")) do |file|
          agent_name = File.basename(file, ".ddl")
          json_file = File.join(agent_dir, "%s.json" % agent_name)

          ddl = DDL.new(agent_name, :agent, false)
          ddl.instance_eval(File.read(file))

          data = {
              "$schema" => "https://choria.io/schemas/mcorpc/ddl/v1/agent.json",
              "metadata" => ddl.meta,
              "actions" => [],
          }

          ddl.actions.sort.each do |action|
            data["actions"] << ddl.action_interface(action)
          end

          File.open(json_file, "w") do |jddl|
            jddl.print(JSON.pretty_generate(data))
          end

          plugin.packagedata[:common][:files] << "agent/%s.json" % agent_name
        end
      # else
      #  raise(GenerateJsonDirNotFoundError) # Need to Mock this out
      end

    end

    # Fetch and return metadata from plugin DDL
    def self.get_metadata(path, type)
      ddl = DDL.new("package", type.to_sym, false)

      begin
        ddl_file = File.read(Dir.glob(File.join(path, type, "*.ddl")).first)
      rescue Exception # rubocop:disable Lint/RescueException
        raise "failed to load ddl file in plugin directory : #{File.join(path, type)}"
      end
      ddl.instance_eval ddl_file

      [ddl.meta, ddl.requirements[:mcollective]]
    end

    # Checks if a directory is present and not empty
    def self.check_dir_present(path)
      (File.directory?(path) && !Dir.glob(File.join(path, "*")).empty?)
    end

    # Quietly calls a block if verbose parameter is false
    def self.execute_verbosely(verbose, &block)
      if verbose
        block.call
      else
        old_stdout = $stdout.clone
        $stdout.reopen(File.new("/dev/null", "w"))
        begin
          block.call
        rescue Exception # rubocop:disable Lint/RescueException
          $stdout.reopen old_stdout
          raise
        ensure
          $stdout.reopen old_stdout
        end
      end
    end

    # Checks if a build tool is present on the system
    def self.command_available?(build_tool)
      ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
        builder = File.join(path, build_tool)
        return true if File.exist?(builder)
      end
      false
    end

    def self.safe_system(*args)
      raise("Failed: #{args.join(' ')}") unless system(*args)
    end

    # Filter out platform specific dependencies
    # Given a list of dependencies named -
    # debian::foo
    # redhat::bar
    # PluginPackager.filter_dependencies('debian', dependencies)
    # will return foo.
    def self.filter_dependencies(prefix, dependencies)
      dependencies.map do |dependency|
        if dependency[:name] =~ /^(\w+)::(\w+)/
          if prefix == $1
            dependency[:name] = $2
            dependency
          end
        else
          dependency
        end
      end.reject(&:nil?)
    end

    # Return the path to a plugin's core directories
    def self.get_plugin_path(target)
      if File.exist?(File.join(target, "lib", "mcollective"))
        return File.join(target, "lib", "mcollective")
      end

      target
    end
  end
end
