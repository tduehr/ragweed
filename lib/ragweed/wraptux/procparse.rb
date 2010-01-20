## Parse the /proc/pid/maps file for
## a particular process

module Ragweed; end
module Ragweed::Wraptux; end

module Ragweed::Wraptux::ProcParse
    ## Returns a hash:
    ## 0x<BaseAddr> => /lib/name_of_lib.1.0.so
    def procparse
        shared_objects = Hash.new
        File.read("/proc/#{@pid}/maps").each do |line|
            if line =~ /[a-zA-Z0-9].so/ && line =~ /xp /
                lib = line.split(' ', 6)
                sa = line.split('-', 0)

                if lib[5] =~ /vdso/
                    next
                end
                lib = lib[5].strip
                lib.gsub!(/[\s\n]+/, "")
                shared_objects.store(sa[0], lib)
            end
        end
        return shared_objects
    end
end
