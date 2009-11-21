
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

ensure_in_path 'lib'
require 'ragweed'

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name 'ragweed'
  ignore_file '.gitignore'
  authors 'tduehr, tqbf, struct'
  email 'td@matasano.com'
  description 'General debugging tool written in Ruby for OSX/Win32/Linux'
  summary 'Scriptable debugger'
  exclude << %w(old$)
  url 'http://github.com/tduehr/ragweed/tree/master'
  version Ragweed::VERSION
  rdoc.opts << "--inline-source"
  rdoc.opts << "--line-numbers"
  spec.opts << '--color'
}
# EOF
