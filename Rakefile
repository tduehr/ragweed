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
PROJ.authors = 'tduehr, tqbf, struct'
PROJ.email = 'td@matasano.com'
PROJ.url = 'github.com/tduehr/ragweed'
PROJ.version = Ragweed::VERSION
PROJ.rubyforge.name = 'ragweed'

PROJ.spec.opts << '--color'

# EOF
