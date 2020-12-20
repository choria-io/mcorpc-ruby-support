# discovers against a flatfile instead of the traditional network discovery
# the flat file must have a node name per line which should match identities
# as configured
module MCollective
  class Discovery
    class Flatfile
      def self.discover(filter, timeout, limit=0, client=nil)
        if client.options[:discovery_options].empty?
          raise "The flatfile discovery method needs a path to a text file"
        else
          file = client.options[:discovery_options].first
        end

        raise "Cannot read the file %s specified as discovery source" % file unless File.readable?(file)

        discovered = []
        hosts = []

        File.readlines(file).each do |host|
          host = host.chomp.strip
          next if host.empty? || host.match(/^#/)
          raise 'Identities can only match /^[\w\.\-]+$/' unless host.match(/^[\w.\-]+$/)

          hosts << host
        end

        # this plugin only supports identity filters, do regex matches etc against
        # the list found in the flatfile
        if !filter["identity"].empty?
          filter["identity"].each do |identity|
            identity = Regexp.new(identity.gsub("\/", "")) if identity.match("^/")

            if identity.is_a?(Regexp)
              discovered = hosts.grep(identity)
            elsif hosts.include?(identity)
              discovered << identity
            end
          end
        else
          discovered = hosts
        end

        discovered
      end
    end
  end
end
