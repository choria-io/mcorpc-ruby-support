class MCollective::Application::Inventory < MCollective::Application # rubocop:disable Style/ClassAndModuleChildren
  description "General reporting tool for nodes, collectives and subcollectives"

  option :script,
         :description => "Script to run",
         :arguments => ["--script SCRIPT"]

  option :collectives,
         :description => "List all known collectives",
         :arguments => ["--list-collectives", "--lc"],
         :default => false,
         :type => :bool

  option :collectivemap,
         :description => "Create a DOT graph of all collectives",
         :arguments => ["--collective-graph MAP", "--cg MAP", "--map MAP"]

  attr_writer :page_length, :page_heading, :page_body

  def post_option_parser(configuration)
    configuration[:node] = ARGV.shift unless ARGV.empty?
  end

  def validate_configuration(configuration)
    unless configuration[:node] || configuration[:script] || configuration[:collectives] || configuration[:collectivemap]
      raise "Need to specify either a node name, script to run or other options"
    end
  end

  # Get all the known collectives and nodes that belong to them
  def fetch_collectives
    util = rpcclient("rpcutil")
    util.progress = false

    collectives = {}
    nodes = 0
    total = 0

    util.collective_info do |_r, cinfo|
      if cinfo[:data] && cinfo[:data][:collectives]
        cinfo[:data][:collectives].each do |collective|
          collectives[collective] ||= []
          collectives[collective] << cinfo[:sender]
        end

        nodes += 1
        total += 1
      end
    end

    {:collectives => collectives, :nodes => nodes, :total_nodes => total}
  end

  # Writes a crude DOT graph to a file
  def collectives_map(file)
    File.open(file, "w") do |graph|
      puts "Retrieving collective info...."
      collectives = fetch_collectives

      graph.puts "graph {"

      collectives[:collectives].keys.sort.each do |collective|
        graph.puts '   subgraph "%s" {' % [collective]

        collectives[:collectives][collective].each do |member|
          graph.puts '      "%s" -- "%s"' % [member, collective]
        end

        graph.puts "   }"
      end

      graph.puts "}"

      puts "Graph of #{collectives[:total_nodes]} nodes has been written to #{file}"
    end
  end

  # Prints a report of all known sub collectives
  def collectives_report
    collectives = fetch_collectives

    puts "   %-30s %s" % ["Collective", "Nodes"]
    puts "   %-30s %s" % ["==========", "====="]

    collectives[:collectives].sort_by {|_key, count| count.size}.each do |collective|
      puts "   %-30s %d" % [collective[0], collective[1].size]
    end

    puts
    puts "   %30s %d" % ["Total nodes:", collectives[:nodes]]
    puts
  end

  def node_inventory # rubocop:disable Metrics/MethodLength
    node = configuration[:node]

    util = rpcclient("rpcutil")
    util.identity_filter node
    util.progress = false

    nodestats = util.custom_request("daemon_stats", {}, node, {"identity" => node}).first

    unless nodestats
      warn "Did not receive any results from node #{node}"
      exit 1
    end

    if nodestats[:statuscode] == 0
      util.custom_request("inventory", {}, node, {"identity" => node}).each do |resp|
        unless resp[:statuscode] == 0
          warn "Failed to retrieve inventory for #{node}: #{resp[:statusmsg]}"
          next
        end

        data = resp[:data]

        begin
          puts "Inventory for #{resp[:sender]}:"
          puts

          nodestats = nodestats[:data]

          puts "   Server Statistics:"
          puts "                      Version: #{nodestats[:version]}"
          puts "                   Start Time: #{Time.at(nodestats[:starttime])}"
          puts "                  Config File: #{nodestats[:configfile]}"
          puts "                  Collectives: #{data[:collectives].join(', ')}" if data.include?(:collectives)
          puts "              Main Collective: #{data[:main_collective]}" if data.include?(:main_collective)
          puts "                   Process ID: #{nodestats[:pid]}"
          puts "               Total Messages: #{nodestats[:total]}"
          puts "      Messages Passed Filters: #{nodestats[:passed]}"
          puts "            Messages Filtered: #{nodestats[:filtered]}"
          puts "             Expired Messages: #{nodestats[:ttlexpired]}"
          puts "                 Replies Sent: #{nodestats[:replies]}"
          puts "         Total Processor Time: #{nodestats[:times][:utime]} seconds"
          puts "                  System Time: #{nodestats[:times][:stime]} seconds"

          puts

          puts "   Agents:"
          if !data[:agents].empty?
            data[:agents].sort.in_groups_of(3, "") do |agents|
              puts "      %-15s %-15s %-15s" % agents
            end
          else
            puts "      No agents installed"
          end

          puts

          puts "   Data Plugins:"
          if !data[:data_plugins].empty?
            data[:data_plugins].sort.in_groups_of(3, "") do |plugins|
              puts "      %-15s %-15s %-15s" % plugins.map {|p| p.gsub("_data", "")}
            end
          else
            puts "      No data plugins installed"
          end

          puts

          puts "   Configuration Management Classes:"
          if !data[:classes].empty?
            field_size = MCollective::Util.field_size(data[:classes], 30)
            fields_num = MCollective::Util.field_number(field_size)
            format = "   #{" %-#{field_size}s" * fields_num}"

            data[:classes].sort.in_groups_of(fields_num, "") do |klasses|
              puts format % klasses
            end
          else
            puts "      No classes applied"
          end

          puts

          puts "   Facts:"
          if !data[:facts].empty?
            data[:facts].sort_by {|f| f[0]}.each do |f|
              puts "      #{f[0]} => #{f[1]}"
            end
          else
            puts "      No facts known"
          end

          break
        rescue Exception => e # rubocop:disable Lint/RescueException
          warn "Failed to display node inventory: #{e.class}: #{e}"
        end
      end
    else
      warn "Failed to retrieve daemon_stats from #{node}: #{nodestats[:statusmsg]}"
    end

    halt util.stats
  end

  # Helpers to create a simple DSL for scriptlets
  def format(fmt)
    @fmt = fmt
  end

  def fields(&blk)
    @flds = blk
  end

  def identity
    @node[:identity]
  end

  def facts
    @node[:facts]
  end

  def classes
    @node[:classes]
  end

  def agents
    @node[:agents]
  end

  # Expects a simple printf style format and apply it to
  # each node:
  #
  #    inventory do
  #        format "%s:\t\t%s\t\t%s"
  #
  #        fields { [ identity, facts["serialnumber"], facts["productname"] ] }
  #    end
  def inventory(&blk)
    raise "Need to give a block to inventory" unless block_given?

    blk.call if block_given?

    raise "Need to define a format" if @fmt.nil?
    raise "Need to define inventory fields" if @flds.nil?

    util = rpcclient("rpcutil")
    util.progress = false

    util.inventory do |_t, resp|
      @node = {:identity => resp[:sender],
               :facts => resp[:data][:facts],
               :classes => resp[:data][:classes],
               :agents => resp[:data][:agents]}

      puts @fmt % @flds.call
    end
  end

  # Use the ruby formatr gem to build reports using Perls formats
  #
  # It is kind of ugly but brings a lot of flexibility in report
  # writing without building an entire reporting language.
  #
  # You need to have formatr installed to enable reports like:
  #
  #    formatted_inventory do
  #        page_length 20
  #
  #        page_heading <<TOP
  #
  #                Node Report @<<<<<<<<<<<<<<<<<<<<<<<<<
  #                            time
  #
  #    Hostname:         Customer:     Distribution:
  #    -------------------------------------------------------------------------
  #    TOP
  #
  #        page_body <<BODY
  #
  #    @<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  #    identity,    facts["customer"], facts["lsbdistdescription"]
  #                                    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  #                                    facts["processor0"]
  #    BODY
  #    end
  def formatted_inventory(&blk)
    require "formatr"

    raise "Need to give a block to formatted_inventory" unless block_given?

    blk.call if block_given?

    raise "Need to define page body format" if @page_body.nil?

    body_fmt = FormatR::Format.new(@page_heading, @page_body)
    body_fmt.setPageLength(@page_length)
    time = Time.now

    util = rpcclient("rpcutil")
    util.progress = false

    util.inventory do |t, resp|
      @node = {:identity => resp[:sender],
               :facts => resp[:data][:facts],
               :classes => resp[:data][:classes],
               :agents => resp[:data][:agents]}

      body_fmt.printFormat(binding)
    end
  rescue Exception => e # rubocop:disable Lint/RescueException
    warn "Could not create report: #{e.class}: #{e}"
    exit 1
  end

  @fmt = nil
  @flds = nil
  @page_heading = nil
  @page_body = nil
  @page_length = 40

  def main
    if configuration[:script]
      if File.exist?(configuration[:script])
        eval(File.read(configuration[:script])) # rubocop:disable Security/Eval
      else
        raise "Could not find script to run: #{configuration[:script]}"
      end

    elsif configuration[:collectivemap]
      collectives_map(configuration[:collectivemap])

    elsif configuration[:collectives]
      collectives_report

    else
      node_inventory
    end
  end
end
