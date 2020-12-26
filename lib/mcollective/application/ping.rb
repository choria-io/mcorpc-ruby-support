module MCollective
  class Application::Ping < Application # rubocop:disable Style/ClassAndModuleChildren
    description "Ping all nodes"

    external(:command => "choria", :args => ["ping"])
    external_help(:command => "choria", :args => ["ping", "--help"])
  end
end
