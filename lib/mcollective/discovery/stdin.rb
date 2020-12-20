# discovers against stdin instead of the traditional network discovery
# the input must be a flat file with a node name per line which should match identities as configured,
# or it should be a json string as output by the -j option of mco rpc
require "mcollective/rpc/helpers"

module MCollective
  class Discovery
    class Stdin
      def self.discover(filter, timeout, limit=0, client=nil)
        if client.options[:discovery_options].empty?
          type = "auto"
        else
          type = client.options[:discovery_options].first.downcase
        end

        discovered = []

        file = $stdin.read

        raise("data piped on STDIN contained only whitespace - could not discover hosts from it.") if file =~ /^\s*$/

        if type == "auto"
          if file =~ /^\s*\[/
            type = "json"
          else
            type = "text"
          end
        end

        Log.debug("Parsing STDIN input as type %s" % type)

        case type
        when "json"
          hosts = RPC::Helpers.extract_hosts_from_json(file)
        when "text"
          hosts = file.split("\n")
        else
          raise("stdin discovery plugin only knows the types auto/text/json, not \"#{type}\"")
        end

        hosts.map do |host|
          raise 'Identities can only match /\w\.\-/' unless host.match(/^[\w.\-]+$/)

          host
        end

        # this plugin only supports identity filters, do regex matches etc against
        # the list found in the flatfile
        if filter["identity"].empty?
          discovered = hosts
        else
          filter["identity"].each do |identity|
            identity = Regexp.new(identity.gsub("\/", "")) if identity.match("^/")

            if identity.is_a?(Regexp)
              discovered = hosts.grep(identity)
            elsif hosts.include?(identity)
              discovered << identity
            end
          end
        end

        discovered
      end
    end
  end
end
