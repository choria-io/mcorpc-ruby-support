class MCollective::Application::Inventory < MCollective::Application # rubocop:disable Style/ClassAndModuleChildren
  description "General reporting tool for nodes, collectives and subcollectives"

  external(:command => "choria", :args => ["inventory"])
  external_help(:command => "choria", :args => ["inventory", "--help"])
end
