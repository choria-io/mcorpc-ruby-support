module MCollective
  class Discovery
    def initialize(client)
      @client = client
    end

    def find_known_methods
      ["broadcast", "mc", "inventory", "flatfile", "external", "choria", "file"]
    end

    def has_method?(method)
      find_known_methods.include?(method)
    end

    def force_direct_mode?
      true
    end

    def discovery_method
      if @client.options[:discovery_method]
        method = @client.options[:discovery_method]
      else
        method = Config.instance.default_discovery_method
      end

      raise "Unknown discovery method %s" % method unless has_method?(method)

      raise "Custom discovery methods require direct addressing mode" if method != "mc" && !Config.instance.direct_addressing

      method
    end

    def discovery_class
      Delegate
    end

    def check_capabilities(filter)
      true
    end

    def ddl
      @ddl ||= DDL.new(discovery_method, :discovery)

      # if the discovery method got changed we might have an old DDL cached
      # this will detect that and reread the correct DDL from disk
      @ddl = DDL.new(discovery_method, :discovery) unless @ddl.meta[:name] == discovery_method

      @ddl
    end

    # checks if compound filters are used and then forces the 'mc' discovery plugin
    def force_discovery_method_by_filter(filter)
      false
    end

    def timeout_for_compound_filter(compound_filter)
      0
    end

    def discovery_timeout(timeout, filter)
      timeout || ddl.meta[:timeout]
    end

    def discover(filter, timeout, limit, client)
      raise "Limit has to be an integer" unless limit.is_a?(Integer)

      discovered = discovery_class.discover(filter, discovery_timeout(timeout, filter), limit, client)

      if limit > 0
        discovered[0, limit]
      else
        discovered
      end
    end
  end
end
