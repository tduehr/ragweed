# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

ensure_in_path 'lib'
require 'ragweed'

task :default => 'spec:run'

PROJ.name = 'ragweed'
PROJ.ignore_file = '.gitignore'
PROJ.authors = 'tduehr, tqbf, struct'
PROJ.email = 'td@matasano.com'
PROJ.description = 'General debugging tool written in Ruby for OSX/Win32/Linux'
PROJ.url = 'http://github.com/tduehr/ragweed/tree/master'
PROJ.version = Ragweed::VERSION
# PROJ.rubyforge.name = 'ragweed'

PROJ.spec.opts << '--color'

# EOF
