class MCollective::Application::Rpc < MCollective::Application # rubocop:disable Style/ClassAndModuleChildren
  description "Generic RPC agent client application"

  external(:command => "choria", :args => ["req"])
  external_help(:command => "choria", :args => ["req", "--help"])
end
