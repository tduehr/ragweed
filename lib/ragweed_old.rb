require 'libmatty'

module Ragweed; end

pkgs = %w[arena sbuf ptr process event rasm blocks detour trampoline device debugger hooks]
pkgs << 'wrap32' if RUBY_PLATFORM =~ /win(dows|32)/i
pkgs << 'wrapx' if RUBY_PLATFORM =~ /darwin/i
pkgs << 'wraptux' if RUBY_PLATFORM =~ /linux/i
pkgs.each do |x|
  require File.dirname(__FILE__) + "/#{x}"
end
