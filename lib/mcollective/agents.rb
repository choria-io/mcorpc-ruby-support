module MCollective
  # A collection of agents, loads them, reloads them and dispatches messages to them.
  # It uses the PluginManager to store, load and manage instances of plugins.
  class Agents
    def initialize(agents={})
      @config = Config.instance
      raise "Configuration has not been loaded, can't load agents" unless @config.configured

      @@agents = agents # rubocop:disable Style/ClassVars

      loadagents
    end

    # Deletes all agents
    def clear!
      @@agents.each_key do |agent|
        PluginManager.delete "#{agent}_agent"
        Util.unsubscribe(Util.make_subscriptions(agent, :broadcast))
      end

      @@agents = {} # rubocop:disable Style/ClassVars
    end

    # Loads all agents from disk
    def loadagents
      Log.debug("Reloading all agents from disk")

      clear!

      @config.libdir.each do |libdir|
        agentdir = "#{libdir}/mcollective/agent"
        next unless File.directory?(agentdir)

        Dir.new(agentdir).grep(/\.rb$/).each do |agent|
          agentname = File.basename(agent, ".rb")
          loadagent(agentname) unless PluginManager.include?("#{agentname}_agent")
        end
      end
    end

    # Loads a specified agent from disk if available
    def loadagent(agentname)
      agentfile = findagentfile(agentname)
      return false unless agentfile

      classname = class_for_agent(agentname)

      PluginManager.delete("#{agentname}_agent")

      begin
        single_instance = ["registration", "discovery"].include?(agentname)

        PluginManager.loadclass(classname)

        if activate_agent?(agentname)
          PluginManager << {:type => "#{agentname}_agent", :class => classname, :single_instance => single_instance}

          # Attempt to instantiate the agent once so any validation and hooks get run
          # this does a basic sanity check on the agent as a whole, if this fails it
          # will be removed from the plugin list
          PluginManager["#{agentname}_agent"]

          Util.subscribe(Util.make_subscriptions(agentname, :broadcast)) unless @@agents.include?(agentname)

          @@agents[agentname] = {:file => agentfile}
          true
        else
          Log.debug("Not activating agent #{agentname} due to agent policy in activate? method")
          false
        end
      rescue Exception # rubocop:disable Lint/RescueException
        Log.error("Loading agent %s failed: %s" % [agentname, $!])
        PluginManager.delete("%s_agent" % agentname)

        false
      end
    end

    # Builds a class name string given a Agent name
    def class_for_agent(agent)
      "MCollective::Agent::#{agent.capitalize}"
    end

    # Checks if a plugin should be activated by
    # calling #activate? on it if it responds to
    # that method else always activate it
    def activate_agent?(agent)
      klass = Kernel.const_get("MCollective").const_get("Agent").const_get(agent.capitalize)

      if klass.respond_to?("activate?")
        klass.activate?
      else
        Log.debug("#{klass} does not have an activate? method, activating as default")
        true
      end
    rescue Exception # rubocop:disable Lint/RescueException
      Log.warn("Agent activation check for %s #{agent} failed: %s: %s" % [agent, $!.class, $!])
      false
    end

    # searches the libdirs for agents
    def findagentfile(agentname)
      @config.libdir.each do |libdir|
        agentfile = File.join([libdir, "mcollective", "agent", "#{agentname}.rb"])
        if File.exist?(agentfile)
          Log.debug("Found #{agentname} at #{agentfile}")
          return agentfile
        end
      end
      false
    end

    # Determines if we have an agent with a certain name
    def include?(agentname)
      PluginManager.include?("#{agentname}_agent")
    end

    # Dispatches a message to an agent, accepts a block that will get run if there are
    # any replies to process from the agent
    def dispatch(request, connection)
      Log.debug("Dispatching a message to agent #{request.agent}")

      Thread.new do
        begin
          agent = PluginManager["#{request.agent}_agent"]

          Timeout.timeout(agent.timeout) do
            replies = agent.handlemsg(request.payload, connection)

            # Agents can decide if they wish to reply or not,
            # returning nil will mean nothing goes back to the
            # requestor
            yield(replies) unless replies.nil?
          end
        rescue Timeout::Error
          Log.warn("Timeout while handling message for %s" % request.agent)
        rescue Exception # rubocop:disable Lint/RescueException
          Log.error("Execution of %s failed: %s" % [request.agent, $!])
          Log.error(e.backtrace.join("\n\t\t"))
        end
      end
    end

    # Get a list of agents that we have
    def self.agentlist
      @@agents.keys
    end
  end
end
