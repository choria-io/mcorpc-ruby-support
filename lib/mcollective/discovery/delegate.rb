module MCollective
  class Discovery
    class Delegate
      def self.binary_name
        "choria"
      end

      def self.discover(filter, timeout, limit, client)
        raise("Cannot find the choria binary in your path") unless Util.command_in_path?("choria")

        cmd = [binary_name, "discover", "-j", "--silent"]

        cmd << "-T" << filter["collective"] if filter["collective"]

        filter.fetch("identity", []).each do |i|
          cmd << "-I" << i
        end

        filter.fetch("cf_class", []).each do |c|
          cmd << "-C" << c
        end

        filter.fetch("fact", []).each do |f|
          cmd << "-F" << "%s%s%s" % [f[:fact], f[:operator], f[:value]]
        end

        filter.fetch("agent", []).each do |a|
          cmd << "-A" << a
        end

        filter.fetch("compound", []).each do |c|
          next unless c.is_a?(Array)

          cmd << "-S" << c.first["expr"]
        end

        client.options.fetch(:discovery_options, []).each do |opt|
          cmd << "--do" << opt
        end

        cmd << "--dm" << (client.options.fetch(:discovery_method, "broadcast") rescue "broadcast")

        run_discover(cmd, timeout)
      end

      def self.run_discover(cmd, timeout)
        nodes = []

        Log.debug("Executing choria for discovery using: %s" % cmd.join(" "))

        Open3.popen3(ENV, *cmd) do |stdin, stdout, stderr, wait_thr|
          stdin.close

          begin
            Timeout.timeout(timeout + 0.5) do
              status = wait_thr.value

              raise("Choria discovery failed: %s" % stderr.read) unless status.exitstatus == 0
            end
          rescue Timeout::Error
            Log.warn("Timeout waiting for Choria to perform discovery")
            Process.kill("KILL", wait_thr[:pid])
            raise("Choria failed to complete discovery within %d timeout" % timeout)
          end

          nodes.concat(JSON.parse(stdout.read))
        end

        nodes
      end
    end
  end
end
