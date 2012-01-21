# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "mini_record/version"

Gem::Specification.new do |s|
  s.name        = "mini_record"
  s.version     = MiniRecord::VERSION
  s.authors     = ["Davide D'Agostino"]
  s.email       = ["d.dagostino@lipsiasoft.com"]
  s.homepage    = "https://github.com/DAddYE/mini_record"
  s.summary     = %q{MiniRecord is a micro gem that allow you to write schema inside your model as you can do in DataMapper.}
  s.description = %q{
    With it you can add the ability to create columns outside the default schema, directly
    in your model in a similar way that you just know in others projects
    like  DataMapper or  MongoMapper.
  }.gsub(/^ {4}/, '')

  s.rubyforge_project = "mini_record"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_dependency "activerecord", "~>3.2.0"
end
