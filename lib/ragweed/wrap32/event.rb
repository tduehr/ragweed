class Ragweed::Event
  # Quick wrapper around Win32 events. Events are simple thread sync
  # objects that are cross-process. They are like semaphores that you
  # can select() on. 

  # You can just do WinEvent.new to get a new anonymous handle, and
  # then call .handle on it to find out what the handle was. Communicate
  # your pid and the handle value, somehow, to a remote process. That
  # process can get the same event by passing a WinProcess and the
  # handle here. 
  # 
  # So, in Process1 (assume pid 668, and handle 300):
  #
  # e = WinEvent.new
  # puts #{ get_current_process_id }: #{ e.handle }"
  #
  # And in Process2:
  #
  # e = WinEvent.new(WinProcess.new(668), 300)
  #
  # Now both processes share an event.
  def initialize(p=nil, h=nil)
    @p = p
    @h = (@p.dup_handle(h) if h) || create_event
  end

  # Don't return until the event is signalled. Note that you
  # can't break this with timeouts or CTR-C.
  def wait
    Ragweed::Wrap32::wait_for_single_object @h
  end

  # Signal the event; anyone waiting on it is now released.
  def signal
    Ragweed::Wrap32::set_event(@h)
  end

  # Force the event back to unsignalled state.
  def reset
    Ragweed::Wrap32::reset_event(@h)
  end

  # A wait loop.
  def on(&block)
    while 1
      wait
      break if not yield
    end
  end
end
