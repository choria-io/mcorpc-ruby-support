module MCollective
  class Application::Ping < Application # rubocop:disable Style/ClassAndModuleChildren
    description "Low level network connectivity test"

    def main
      # If the user did not override the default timeout include the discovery timeout
      if options[:timeout] == 5
        discovery_timeout = options[:disctimeout] || Config.instance.discovery_timeout || 0
        options[:timeout] = options[:timeout] + discovery_timeout
      end
      client = MCollective::Client.new(options)

      start = Time.now.to_f
      times = []

      client.req("ping", "discovery") do |resp|
        times << (Time.now.to_f - start) * 1000

        puts "%-40s time=%.2f ms" % [resp[:senderid], times.last]
      end

      puts("\n\n---- ping statistics ----")

      if !times.empty?
        sum = times.inject(0) {|acc, i| acc + i}
        avg = sum / times.length.to_f

        puts "%d replies max: %.2f min: %.2f avg: %.2f" % [times.size, times.max, times.min, avg]
      else
        puts("No responses received")
      end

      halt client.stats
    end
  end
end
