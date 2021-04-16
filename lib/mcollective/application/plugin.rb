module MCollective
  class Application::Plugin < Application # rubocop:disable Style/ClassAndModuleChildren
    exclude_argument_sections "common", "filter", "rpc"

    description "MCollective Plugin Application"
    usage <<-END_OF_USAGE
mco plugin package [options] <directory>
       mco plugin info <directory>
       mco plugin doc <plugin>
       mco plugin doc <type/plugin>
       mco plugin generate client <ddl> <target>
       mco plugin generate ddl <json_output> <ruby_output>

          info : Display plugin information including package details.
       package : Create all available plugin packages.
           doc : Display documentation for a specific plugin.
    END_OF_USAGE

    option :postinstall,
           :description => "Post install script",
           :arguments => ["--postinstall POSTINSTALL"],
           :type => String

    option :preinstall,
           :description => "Pre install script",
           :arguments => ["--preinstall PREINSTALL"],
           :type => String

    option :revision,
           :description => "Revision number",
           :arguments => ["--revision REVISION"],
           :type => String

    option :iteration,
           :description => "DEPRECATED - Use --revision instead",
           :arguments => ["--iteration ITERATION"],
           :type => String

    option :vendor,
           :description => "Vendor name",
           :arguments => ["--vendor VENDOR"],
           :type => String

    option :pluginpath,
           :description => "MCollective plugin path",
           :arguments => ["--pluginpath PATH"],
           :type => String

    option :mcname,
           :description => "MCollective type (mcollective, pe-mcollective) that the packages depend on",
           :arguments => ["--mcname NAME"],
           :type => String

    option :mcversion,
           :description => "Version of MCollective that the packages depend on",
           :arguments => ["--mcversion MCVERSION"],
           :type => String

    option :dependency,
           :description => "Adds a dependency to the plugin",
           :arguments => ["--dependency DEPENDENCIES"],
           :type => :array

    option :format,
           :description => "Package output format. Defaults to forge",
           :arguments => ["--format OUTPUTFORMAT"],
           :type => String

    option :sign,
           :description => "Embed a signature in the package",
           :arguments => ["--sign"],
           :type => :boolean

    option :rpctemplate,
           :description => "Template to use.",
           :arguments => ["--template HELPTEMPLATE"],
           :type => String

    option :version,
           :description => "The version of the plugin",
           :arguments => ["--pluginversion VERSION"],
           :type => String

    option :keep_artifacts,
           :description => "Don't remove artifacts after building packages",
           :arguments => ["--keep-artifacts"],
           :type => :boolean

    option :module_template,
           :description => "Path to the template used by the modulepackager",
           :arguments => ["--module-template PATH"],
           :type => String

    # Handle alternative format that optparser can't parse.
    def post_option_parser(configuration)
      if ARGV.length >= 1
        configuration[:action] = ARGV.delete_at(0)

        configuration[:target] = ARGV.delete_at(0) || "."
      end
    end

    # Generate a plugin skeleton
    def generate_command
      puts "CRITICAL: mco plugin generate is deprecated, please use 'choria plugin generate'"
    end

    # Package plugin
    def package_command
      if configuration[:sign] && Config.instance.pluginconf.include?("debian_packager.keyname")
        configuration[:sign] = Config.instance.pluginconf["debian_packager.keyname"]
        configuration[:sign] = "\"#{configuration[:sign]}\"" unless configuration[:sign].match(/".*"/)
      end

      plugin = prepare_plugin
      (configuration[:pluginpath] = "#{configuration[:pluginpath]}/") if configuration[:pluginpath] && !configuration[:pluginpath].match(/^.*\/$/)
      packager = PluginPackager["#{configuration[:format].capitalize}Packager"]
      packager.new(plugin, configuration[:pluginpath], configuration[:sign],
                   options[:verbose], configuration[:keep_artifacts],
                   configuration[:module_template]).create_packages
    end

    # Agents are just called 'agent' but newer plugin types are
    # called plugin_plugintype for example facter_facts etc so
    # this will first try the old way then the new way.
    def load_plugin_ddl(plugin, type)
      [plugin, "#{plugin}_#{type}"].each do |p|
        ddl = DDL.new(p, type, false)
        if ddl.client_activated? && ddl.findddlfile(p, type)
          ddl.loadddlfile
          return ddl
        end
      end

      nil
    end

    # Show application list and plugin help
    def doc_command
      puts "WARNING: mco plugin doc is deprecated, please use choria plugin doc"

      exec("choria plugin doc %s" % [configuration[:target]])
    end

    # Creates the correct package plugin object.
    def prepare_plugin
      plugintype = set_plugin_type unless configuration[:plugintype]
      configuration[:format] = "forge" unless configuration[:format]
      PluginPackager.load_packagers
      plugin_class = PluginPackager[configuration[:plugintype]]

      if configuration[:dependency] && configuration[:dependency].size == 1
        configuration[:dependency] = configuration[:dependency][0].split(" ")
      elsif configuration[:dependency]
        configuration[:dependency].map! {|dep| {:name => dep, :version => nil}}
      end

      mcdependency = {
        :mcname => configuration[:mcname],
        :mcversion => configuration[:mcversion]
      }

      # Deprecation warning for --iteration
      if configuration[:iteration]
        puts "Warning. The --iteration flag has been deprecated. Please use --revision instead."
        configuration[:revision] = configuration[:iteration] unless configuration[:revision]
      end

      plugin_class.new(configuration, mcdependency, plugintype)
    end

    def plugin_directory_exists?(plugin_type)
      File.directory?(File.join(PluginPackager.get_plugin_path(configuration[:target]), plugin_type))
    end

    # Identify plugin type if not provided.
    def set_plugin_type
      if plugin_directory_exists?("agent") || plugin_directory_exists?("application")
        configuration[:plugintype] = "AgentDefinition"
        "Agent"
      elsif plugin_directory_exists?(plugintype = identify_plugin)
        configuration[:plugintype] = "StandardDefinition"
        plugintype
      else
        raise "target directory is not a valid mcollective plugin"
      end
    end

    # If plugintype is StandardDefinition, identify which of the special
    # plugin types we are dealing with based on directory structure.
    # To keep it simple we limit it to one type per target directory.
    # Return the name of the type of plugin as a string
    def identify_plugin
      plugintype = Dir.glob(File.join(configuration[:target], "*")).select do |file|
        File.directory?(file) && file.match(/(connector|facts|registration|security|audit|pluginpackager|discovery|validator)/)
      end

      raise "more than one plugin type detected in directory" if plugintype.size > 1
      raise "no plugins detected in directory" if plugintype.empty?

      File.basename(plugintype[0])
    end

    def main
      abort "No action specified, please run 'mco help plugin' for help" unless configuration.include?(:action)

      cmd = "#{configuration[:action]}_command"

      if respond_to? cmd
        send cmd
      else
        abort "Invalid action #{configuration[:action]}, please run 'mco help plugin' for help."
      end
    end
  end
end
