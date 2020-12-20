module MCollective
  class Application::Help < Application # rubocop:disable Style/ClassAndModuleChildren
    description "Application list and help"
    usage "rpc help [application name]"

    def post_option_parser(configuration)
      configuration[:application] = ARGV.shift unless ARGV.empty?
    end

    def main
      if configuration.include?(:application)
        puts Applications[configuration[:application]].help
      else
        puts "The Marionette Collective version #{MCollective.version}"
        puts

        Applications.list.sort.each do |app|
          begin
            puts "  %-15s %s" % [app, Applications[app].application_description]
          rescue # rubocop:disable Lint/SuppressedException
          end
        end

        puts
      end
    end
  end
end
