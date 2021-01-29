class MCollective::Application::Find < MCollective::Application # rubocop:disable Style/ClassAndModuleChildren
  description "Find hosts using the discovery system matching filter criteria"

  def main
    mc = rpcclient("rpcutil")

    starttime = Time.now

    mc.detect_and_set_stdin_discovery

    nodes = mc.discover

    discoverytime = Time.now - starttime

    $stderr.puts if options[:verbose]

    nodes.each {|c| puts c}

    warn "\nDiscovered %s nodes in %.2f seconds using the %s discovery plugin" % [nodes.size, discoverytime, mc.client.options[:discovery_method]] if options[:verbose]

    !nodes.empty? ? exit(0) : exit(1)
  end
end
