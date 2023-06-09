require_relative "lib/infopark/user_io/version"

Gem::Specification.new do |s|
  s.name = "infopark-user_io"
  s.version = Infopark::UserIO::VERSION
  s.summary = "A utility lib to interact with the user on the command line."
  s.description = s.summary
  s.authors = ["Tilo Prütz"]
  s.email = "tilo@infopark.de"
  s.files = `git ls-files -z`.split("\0")
  s.license = "UNLICENSED"

  s.add_development_dependency "bundler"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rubocop"
end
