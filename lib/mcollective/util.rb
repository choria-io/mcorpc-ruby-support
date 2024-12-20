module MCollective
  # Some basic utility helper methods useful to clients, agents, runner etc.
  module Util
    # Finds out if this MCollective has an agent by the name passed
    #
    # If the passed name starts with a / it's assumed to be regex
    # and will use regex to match
    def self.has_agent?(agent)
      agent = Regexp.new(agent.gsub("\/", "")) if agent.start_with?("/")

      if agent.is_a?(Regexp)
        if !Agents.agentlist.grep(agent).empty?
          true
        else
          false
        end
      else
        Agents.agentlist.include?(agent)
      end
    end

    # On windows ^c can't interrupt the VM if its blocking on
    # IO, so this sets up a dummy thread that sleeps and this
    # will have the end result of being interruptable at least
    # once a second.  This is a common pattern found in Rails etc
    def self.setup_windows_sleeper
      Thread.new { loop { sleep 1 } } if Util.windows?
    end

    # Checks if this node has a configuration management class by parsing the
    # a text file with just a list of classes, recipes, roles etc.  This is
    # ala the classes.txt from puppet.
    #
    # If the passed name starts with a / it's assumed to be regex
    # and will use regex to match
    def self.has_cf_class?(klass)
      klass = Regexp.new(klass.gsub("\/", "")) if klass.start_with?("/")
      cfile = Config.instance.classesfile

      Log.debug("Looking for configuration management classes in #{cfile}")

      begin
        File.readlines(cfile).each do |k|
          case klass
          when Regexp
            return true if k.chomp.match(klass)
          when k.chomp
            return true
          end
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        Log.warn("Parsing classes file '#{cfile}' failed: #{e.class}: #{e}")
      end

      false
    end

    # Gets the value of a specific fact, mostly just a duplicate of MCollective::Facts.get_fact
    # but it kind of goes with the other classes here
    def self.get_fact(fact)
      Facts.get_fact(fact)
    end

    # Compares fact == value,
    #
    # If the passed value starts with a / it's assumed to be regex
    # and will use regex to match
    def self.has_fact?(fact, value, operator)
      Log.debug("Comparing #{fact} #{operator} #{value}")
      Log.debug("where :fact = '#{fact}', :operator = '#{operator}', :value = '#{value}'")

      fact = Facts[fact]
      return false if fact.nil?

      fact = fact.clone
      case fact
      when Array
        fact.any? { |element| test_fact_value(element, value, operator)}
      when Hash
        fact.keys.any? { |element| test_fact_value(element, value, operator)}
      else
        test_fact_value(fact, value, operator)
      end
    end

    def self.test_fact_value(fact, value, operator)
      if operator == "=~"
        # to maintain backward compat we send the value
        # as /.../ which is what 1.0.x needed.  this strips
        # off the /'s which is what we need here
        value = $1 if value =~ /^\/(.+)\/$/

        return true if fact.match(Regexp.new(value))

      elsif operator == "=="
        return true if fact == value

      elsif ["<=", ">=", "<", ">", "!="].include?(operator)
        # Yuk - need to type cast, but to_i and to_f are overzealous
        if value =~ /^[0-9]+$/ && fact =~ /^[0-9]+$/
          fact = Integer(fact) # rubocop:disable Lint/UselessAssignment
          value = Integer(value) # rubocop:disable Lint/UselessAssignment
        elsif value =~ /^[0-9]+.[0-9]+$/ && fact =~ /^[0-9]+.[0-9]+$/
          fact = Float(fact) # rubocop:disable Lint/UselessAssignment
          value = Float(value) # rubocop:disable Lint/UselessAssignment
        end

        return true if eval("fact #{operator} value") # rubocop:disable Security/Eval, Style/EvalWithLocation
      end

      false
    end
    private_class_method :test_fact_value

    # Checks if the configured identity matches the one supplied
    #
    # If the passed name starts with a / it's assumed to be regex
    # and will use regex to match
    def self.has_identity?(identity)
      identity = Regexp.new(identity.gsub("\/", "")) if identity.start_with?("/")

      case identity
      when Regexp
        return Config.instance.identity.match(identity)
      when Config.instance.identity
        return true
      end

      false
    end

    # Checks if the passed in filter is an empty one
    def self.empty_filter?(filter)
      filter == empty_filter || filter == {}
    end

    # Creates an empty filter
    def self.empty_filter
      {
        "fact" => [],
        "cf_class" => [],
        "agent" => [],
        "identity" => [],
        "compound" => []
      }
    end

    # Returns the PuppetLabs mcollective path for windows
    def self.windows_prefix
      File.join(ENV["ALLUSERSPROFILE"], "PuppetLabs", "choria")
    end

    def self.choria_windows_prefix
      File.join(ENV["ALLUSERSPROFILE"], "choria")
    end

    def self.config_paths_for_user
      config_paths = []

      ["~/.choriarc", "~/.mcollective"].each do |f|
        begin
          # File.expand_path will raise if HOME isn't set, catch it
          config_paths << File.expand_path(f)
        rescue ArgumentError # rubocop:disable Lint/SuppressedException
        end
      end

      if windows?
        config_paths << File.join(choria_windows_prefix, "etc", "client.conf")
        config_paths << File.join(windows_prefix, "etc", "client.cfg")
      else
        config_paths << "/etc/choria/client.conf"
        config_paths << "/usr/local/etc/choria/client.conf"
        config_paths << "/etc/puppetlabs/mcollective/client.cfg"
        config_paths << "/etc/mcollective/client.cfg"
        config_paths << "/usr/local/etc/mcollective/client.cfg"
      end

      config_paths
    end

    # Picks the default user config file, priorities are first Choria ones then old MCollective ones
    #
    # In roughly this order, first to exist is used:
    #
    # - ~/.choriarc
    # - ~/.mcollective
    #
    # On Unix:
    #
    # - /etc/choria/client.conf
    # - /usr/local/etc/choria/client.conf
    # - /etc/puppetlabs/mcollective/client.cfg
    # - /etc/mcollective/client.cfg
    # - /usr/local/etc/mcollective/client.cfg
    #
    # On Windows:
    #
    # - APPData/ChoriaIO/choria/etc/client.conf on windows
    # - APPData/PuppetLabs/mcollective/etc/client.cfg on windows
    def self.config_file_for_user
      config_paths = config_paths_for_user

      found = config_paths.find_index { |file| File.readable?(file) } || 0

      config_paths[found]
    end

    # Creates a standard options hash
    def self.default_options
      {
        :verbose => false,
        :disctimeout => nil,
        :timeout => 5,
        :config => config_file_for_user,
        :collective => nil,
        :discovery_method => nil,
        :discovery_options => Config.instance.default_discovery_options,
        :filter => empty_filter,
        :federations => Config.instance.federations
      }
    end

    def self.make_subscriptions(agent, type, collective=nil)
      config = Config.instance

      raise("Unknown target type #{type}") unless [:broadcast, :directed, :reply].include?(type)

      if collective.nil?
        config.collectives.map do |c|
          {:agent => agent, :type => type, :collective => c}
        end
      else
        raise("Unknown collective '#{collective}' known collectives are '#{config.collectives.join ', '}'") unless config.collectives.include?(collective)

        [{:agent => agent, :type => type, :collective => collective}]
      end
    end

    # Helper to subscribe to a topic on multiple collectives or just one
    def self.subscribe(targets)
      connection = PluginManager["connector_plugin"]

      targets = [targets].flatten

      targets.each do |target|
        connection.subscribe(target[:agent], target[:type], target[:collective])
      end
    end

    # Helper to unsubscribe to a topic on multiple collectives or just one
    def self.unsubscribe(targets)
      connection = PluginManager["connector_plugin"]

      targets = [targets].flatten

      targets.each do |target|
        connection.unsubscribe(target[:agent], target[:type], target[:collective])
      end
    end

    # Wrapper around PluginManager.loadclass
    def self.loadclass(klass)
      PluginManager.loadclass(klass)
    end

    # Parse a fact filter string like foo=bar into the tuple hash thats needed
    def self.parse_fact_string(fact)
      case fact
      when /^([^ ]+?) *=> *(.+)/
        {:fact => $1, :value => $2, :operator => ">="}
      when /^([^ ]+?) *=< *(.+)/
        {:fact => $1, :value => $2, :operator => "<="}
      when /^([^ ]+?) *(<=|>=|<|>|!=|==|=~) *(.+)/
        {:fact => $1, :value => $3, :operator => $2}
      when /^(.+?) *= *\/(.+)\/$/
        {:fact => $1, :value => "/#{$2}/", :operator => "=~"}
      when /^([^= ]+?) *= *(.+)/
        {:fact => $1, :value => $2, :operator => "=="}
      else
        raise "Could not parse fact #{fact} it does not appear to be in a valid format"
      end
    end

    # Escapes a string so it's safe to use in system() or backticks
    #
    # Taken from Shellwords#shellescape since it's only in a few ruby versions
    def self.shellescape(str)
      return "''" if str.empty?

      str = str.dup

      # Process as a single byte sequence because not all shell
      # implementations are multibyte aware.
      str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")

      # A LF cannot be escaped with a backslash because a backslash + LF
      # combo is regarded as line continuation and simply ignored.
      str.gsub!(/\n/, "'\n'")

      str
    end

    def self.windows?
      !!(RbConfig::CONFIG["host_os"] =~ /mswin|win32|dos|mingw|cygwin/i)
    end

    # Return color codes, if the config color= option is false
    # just return a empty string
    def self.color(code)
      colorize = Config.instance.color

      colors = {
        :red => "[31m",
        :green => "[32m",
        :yellow => "[33m",
        :cyan => "[36m",
        :bold => "[1m",
        :reset => "[0m"
      }

      if colorize
        colors[code] || ""
      else
        ""
      end
    end

    # Helper to return a string in specific color
    def self.colorize(code, msg)
      "%s%s%s" % [color(code), msg, color(:reset)]
    end

    # Returns the current ruby version as per RUBY_VERSION, mostly
    # doing this here to aid testing
    def self.ruby_version
      RUBY_VERSION
    end

    def self.mcollective_version
      MCollective::VERSION
    end

    # Returns an aligned_string of text relative to the size of the terminal
    # window. If a line in the string exceeds the width of the terminal window
    # the line will be chopped off at the whitespace chacter closest to the
    # end of the line and prepended to the next line, keeping all indentation.
    #
    # The terminal size is detected by default, but custom line widths can
    # passed. All strings will also be left aligned with 5 whitespace characters
    # by default.
    def self.align_text(text, console_cols=nil, preamble=5)
      unless console_cols
        console_cols = terminal_dimensions[0]

        # if unknown size we default to the typical unix default
        console_cols = 80 if console_cols == 0
      end

      console_cols -= preamble

      # Return unaligned text if console window is too small
      return text if console_cols <= 0

      # If console is 0 this implies unknown so we assume the common
      # minimal unix configuration of 80 characters
      console_cols = 80 if console_cols <= 0

      text = text.split("\n")
      piece = ""
      whitespace = 0

      text.each_with_index do |line, i|
        whitespace = 0

        whitespace += 1 while whitespace < line.length && line[whitespace].chr == " "

        # If the current line is empty, indent it so that a snippet
        # from the previous line is aligned correctly.
        line = (" " * whitespace) if line == ""

        # If text was snipped from the previous line, prepend it to the
        # current line after any current indentation.
        if piece != ""
          # Reset whitespaces to 0 if there are more whitespaces than there are
          # console columns
          whitespace = 0 if whitespace >= console_cols

          # If the current line is empty and being prepended to, create a new
          # empty line in the text so that formatting is preserved.
          text.insert(i + 1, "") if text[i + 1] && line == (" " * whitespace)

          # Add the snipped text to the current line
          line.insert(whitespace, "#{piece} ")
        end

        piece = ""

        # Compare the line length to the allowed line length.
        # If it exceeds it, snip the offending text from the line
        # and store it so that it can be prepended to the next line.
        if line.length > (console_cols + preamble)
          reverse = console_cols

          reverse -= 1 while line[reverse].chr != " "

          piece = line.slice!(reverse, (line.length - 1)).lstrip
        end

        # If a snippet exists when all the columns in the text have been
        # updated, create a new line and append the snippet to it, using
        # the same left alignment as the last line in the text.
        if piece != "" && text[i + 1].nil?
          text[i + 1] = "#{' ' * whitespace}#{piece}"
          piece = ""
        end

        # Add the preamble to the line and add it to the text
        line = ((" " * preamble) + line)
        text[i] = line
      end

      text.join("\n")
    end

    # Figures out the columns and lines of the current tty
    #
    # Returns [0, 0] if it can't figure it out or if you're
    # not running on a tty
    def self.terminal_dimensions(stdout=$stdout, environment=ENV)
      return [0, 0] unless stdout.tty?

      return [80, 40] if Util.windows?

      if environment["COLUMNS"] && environment["LINES"]
        [environment["COLUMNS"].to_i, environment["LINES"].to_i]

      elsif environment["TERM"] && command_in_path?("tput")
        [`tput cols`.to_i, `tput lines`.to_i]

      elsif command_in_path?("stty")
        `stty size`.scan(/\d+/).map(&:to_i)
      else
        [0, 0]
      end
    rescue
      [0, 0]
    end

    # Checks in PATH returns true if the command is found
    def self.command_in_path?(command)
      found = ENV["PATH"].split(File::PATH_SEPARATOR).map do |p|
        File.exist?(File.join(p, command))
      end

      found.include?(true)
    end

    # compare two software versions as commonly found in
    # package versions.
    #
    # returns 0 if a == b
    # returns -1 if a < b
    # returns 1 if a > b
    #
    # Code originally from Puppet
    def self.versioncmp(version_a, version_b)
      vre = /[-.]|\d+|[^-.\d]+/
      ax = version_a.scan(vre)
      bx = version_b.scan(vre)

      while !ax.empty? && !bx.empty?
        a = ax.shift
        b = bx.shift

        if a == b then next
        elsif a == "-" && b == "-" then next
        elsif a == "-"             then return -1
        elsif b == "-"             then return 1
        elsif a == "." && b == "." then next
        elsif a == "."            then return -1
        elsif b == "."            then return 1
        elsif a =~ /^\d+$/ && b =~ /^\d+$/
          return a.to_s.upcase <=> b.to_s.upcase if a =~ /^0/ || b =~ /^0/

          return a.to_i <=> b.to_i
        else
          return a.upcase <=> b.upcase
        end
      end

      version_a <=> version_b
    end

    # we should really use Pathname#absolute? but it's not in all the
    # ruby versions we support and it comes down to roughly this
    def self.absolute_path?(path, separator=File::SEPARATOR, alt_separator=File::ALT_SEPARATOR)
      if alt_separator
        path_matcher = /^([a-zA-Z]:){0,1}[#{Regexp.quote alt_separator}#{Regexp.quote separator}]/
      else
        path_matcher = /^#{Regexp.quote separator}/
      end

      !!path.match(path_matcher)
    end

    # Converts a string into a boolean value
    # Strings matching 1,y,yes,true or t will return TrueClass
    # Any other value will return FalseClass
    def self.str_to_bool(val)
      clean_val = val.to_s.strip
      case clean_val
      when /^(1|yes|true|y|t)$/i
        true
      when /^(0|no|false|n|f)$/i
        false
      else
        raise("Cannot convert string value '#{clean_val}' into a boolean.")
      end
    end

    # Looks up the template directory and returns its full path
    def self.templatepath(template_file)
      config_dir = File.dirname(Config.instance.configfile)
      template_path = File.join(config_dir, template_file)
      return template_path if File.exist?(template_path)

      File.join("/etc/mcollective", template_file)
    end

    # subscribe to the direct addressing queue
    def self.subscribe_to_direct_addressing_queue
      subscribe(make_subscriptions("mcollective", :directed))
    end

    # Get field size for printing
    def self.field_size(elements, min_size=40)
      max_length = elements.max_by(&:length).length
      max_length > min_size ? max_length : min_size
    end

    # Calculate number of fields for printing
    def self.field_number(field_size, max_size=90)
      number = (max_size / field_size).to_i
      number == 0 ? 1 : number
    end

    def self.get_hidden_input_on_windows # rubocop:disable Naming/AccessorMethodName
      require "Win32API"

      # Hook into getch from crtdll. Keep reading all keys till return
      # or newline is hit.
      # If key is backspace or delete, then delete the character and update
      # the buffer.
      input = ""

      while char = Win32API.new("crtdll", "_getch", [], "I").Call
        break if [10, 13].include?(char) # return or newline

        if [127, 8].include?(char) # backspace and delete
          input.slice!(-1, 1) unless input.empty?
        else
          input << char.chr
        end
      end

      input
    end

    def self.get_hidden_input_on_unix # rubocop:disable Naming/AccessorMethodName
      raise "Could not hook to stdin to hide input. If using SSH, try using -t flag while connecting to server." unless $stdin.tty?
      raise "Could not hide input using stty command." unless system "stty -echo -icanon"

      input = $stdin.gets
    ensure
      raise "Could not enable echoing of input. Try executing `stty echo icanon` to debug." unless system "stty echo icanon"

      input
    end

    def self.get_hidden_input(message="Please enter data: ")
      print message unless message.nil?

      if versioncmp(ruby_version, "1.9.3") >= 0
        require "io/console"
        input = $stdin.noecho(&:gets)
      elsif windows? # Use hacks to get hidden input on Ruby <1.9.3
        input = get_hidden_input_on_windows
      else
        input = get_hidden_input_on_unix
      end

      input.chomp! if input

      input
    end
  end
end
