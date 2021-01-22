require "rubygems"
require "rubygems/package_task"

spec = Gem::Specification.load('mcorpc-ruby-support.gemspec')

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
