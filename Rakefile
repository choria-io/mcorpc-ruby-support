require "rubygems"
require "rubygems/package_task"

PROJ_VERSION = "2.22.1"

spec = Gem::Specification.new do |s|
  s.name = "choria-mcorpc-support"
  s.version = PROJ_VERSION
  s.license = "Apache-2.0"
  s.author = "R.I.Pienaar"
  s.email = "rip@devco.net"
  s.homepage = "https://choria.io/"
  s.summary = "Support libraries the Choria Server"
  s.description = "Libraries enabling Ruby support for the Choria Orchestration Server"
  s.files = FileList["{lib,bin}/**/*"].to_a
  s.require_path = "lib"
  s.bindir = "bin"
  s.executables = ["mco"]
  s.add_dependency "systemu", "~> 2.6", ">= 2.6.4"
  s.add_dependency "nats-pure", "~> 0.6"
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar = false
  pkg.need_zip = false
  pkg.package_dir = "build"
end

desc "Run spec tests"
task :test do
  sh "bundle exec rubocop --config .rubocop.yml lib"
  sh "bundle exec rspec"
end

desc "Update JSON DDL files"
task :update_ddl do
  require "mcollective"

  Dir.glob("lib/mcollective/agent/*.ddl") do |ddlfile|
    next if ddlfile =~ /^choria_uril/

    agent_dir = File.dirname(ddlfile)
    agent_name = File.basename(ddlfile, ".ddl")
    json_file = File.join(agent_dir, "%s.json" % agent_name)

    ddl = MCollective::DDL.new(agent_name, :agent, false)
    ddl.instance_eval(File.read(ddlfile))

    data = {
      "$schema" => "https://choria.io/schemas/mcorpc/ddl/v1/agent.json",
      "metadata" => ddl.meta,
      "actions" => []
    }

    ddl.actions.sort.each do |action|
      data["actions"] << ddl.action_interface(action)
    end

    puts "Writing JSON DDL in %s" % json_file

    File.open(json_file, "w") do |jddl|
      jddl.print(JSON.pretty_generate(data))
    end
  end
end
