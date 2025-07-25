PROJ_VERSION = "2.26.5"

Gem::Specification.new do |s|
  s.name = "choria-mcorpc-support"
  s.version = PROJ_VERSION
  s.license = "Apache-2.0"
  s.author = "R.I.Pienaar"
  s.email = "rip@devco.net"
  s.homepage = "https://choria.io/"
  s.summary = "Support libraries the Choria Server"
  s.description = "Libraries enabling Ruby support for the Choria Orchestration Server"
  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  s.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  s.require_path = "lib"
  s.bindir = "bin"
  s.executables = ["mco"]
  s.add_dependency "systemu", "~> 2.6", ">= 2.6.4"
  s.add_dependency "nats-pure", "~> 0.6", "< 0.7.0"
end
