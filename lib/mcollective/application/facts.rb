class MCollective::Application::Facts < MCollective::Application # rubocop:disable Style/ClassAndModuleChildren
  description "Reports on usage for a specific fact"

  external(:command => "choria", :args => ["facts"])
  external_help(:command => "choria", :args => ["facts", "--help"])
end
