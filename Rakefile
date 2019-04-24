require "rubygems"
require "rubygems/package_task"

PROJ_VERSION = "2.21.0"

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
  s.add_dependency "nats-pure", "~> 0.5.0"
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar = false
  pkg.need_zip = false
  pkg.package_dir = "build"
end

desc "Run spec tests"
task :test do
  sh "cd spec && rake"
end
