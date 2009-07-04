## New 'ThreadInfo' sub module
## so Wraptux matches the API 
module Ragweed; end
module Ragweed::Wraptux; end

module Ragweed::Wraptux::ThreadInfo
  ## Return an array of thread PIDs
  def self.get_thread_pids(pid)
   	a = Dir.entries("/proc/#{pid}/task/")
    a.delete_if do |x| x == '.' end
   	a.delete_if do |x| x == '..' end
  end
end
