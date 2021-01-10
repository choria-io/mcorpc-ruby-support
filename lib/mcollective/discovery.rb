module MCollective
  class Discovery
    def initialize(client)
      @known_methods = find_known_methods
      @default_method = Config.instance.default_discovery_method
      @client = client
    end

    def find_known_methods
      PluginManager.find("discovery")
    end

    def has_method?(method)
      @known_methods.include?(method)
    end

    def force_direct_mode?
      discovery_method != "mc"
    end

    def discovery_method
      method = "mc"

      if @client.options[:discovery_method]
        method = @client.options[:discovery_method]
      else
        method = @default_method
      end

      raise "Unknown discovery method %s" % method unless has_method?(method)

      raise "Custom discovery methods require direct addressing mode" if method != "mc" && !Config.instance.direct_addressing

      method
    end

    def discovery_class
      method = discovery_method.capitalize

      PluginManager.loadclass("MCollective::Discovery::#{method}") unless self.class.const_defined?(method)

      self.class.const_get(method)
    end

    def ddl
      @ddl ||= DDL.new(discovery_method, :discovery)

      # if the discovery method got changed we might have an old DDL cached
      # this will detect that and reread the correct DDL from disk
      @ddl = DDL.new(discovery_method, :discovery) unless @ddl.meta[:name] == discovery_method

      @ddl
    end

    # Agent filters are always present no matter what, so we cant raise an error if the capabilities
    # suggest the discovery method cant do agents we just have to rely on the discovery plugin to not
    # do stupid things in the presense of a agent filter
    def check_capabilities(filter)
      capabilities = ddl.discovery_interface[:capabilities]

      raise "Cannot use class filters while using the '%s' discovery method" % discovery_method if !capabilities.include?(:classes) && !filter["cf_class"].empty?

      raise "Cannot use fact filters while using the '%s' discovery method" % discovery_method if !capabilities.include?(:facts) && !filter["fact"].empty?

      raise "Cannot use identity filters while using the '%s' discovery method" % discovery_method if !capabilities.include?(:identity) && !filter["identity"].empty?

      raise "Cannot use compound filters while using the '%s' discovery method" % discovery_method if !capabilities.include?(:compound) && !filter["compound"].empty?
    end

    # checks if compound filters are used and then forces the 'mc' discovery plugin
    def force_discovery_method_by_filter(filter)
      if discovery_method != "mc" && !filter["compound"].empty?
        Log.info "Switching to mc discovery method because compound filters are used"
        @client.options[:discovery_method] = "mc"

        return true
      end

      false
    end

    # if a compound filter is specified and it has any function
    # then we read the DDL for each of those plugins and sum up
    # the timeout declared in the DDL
    def timeout_for_compound_filter(compound_filter)
      return 0 if compound_filter.nil? || compound_filter.empty?

      # disabled while bringing in new compound filters
      # compound_filter.each do |filter|
      #   filter.each do |statement|
      #     next unless statement["fstatement"]
      #
      #     pluginname = Data.pluginname(statement["fstatement"]["name"])
      #     ddl = DDL.new(pluginname, :data)
      #     timeout += ddl.meta[:timeout]
      #   end
      # end

      0
    end

    def discovery_timeout(timeout, filter)
      timeout ||= ddl.meta[:timeout]

      if filter["compound"] && filter["compound"].empty?
        timeout
      else
        timeout + timeout_for_compound_filter(filter["compound"])
      end
    end

    def discover(filter, timeout, limit)
      raise "Limit has to be an integer" unless limit.is_a?(Integer)

      force_discovery_method_by_filter(filter)

      check_capabilities(filter)

      discovered = discovery_class.discover(filter, discovery_timeout(timeout, filter), limit, @client)

      if limit > 0
        discovered[0, limit]
      else
        discovered
      end
    end
  end
end
