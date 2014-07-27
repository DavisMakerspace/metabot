module IRC
  class Client
    def initialize(socket)
      @socket = socket
      @receiver = nil
      @probe = nil
      @buffer = ''
    end
    attr_accessor :receiver, :probe
    def to_io; @socket; end
    def receive
      @buffer += @socket.read_nonblock MAXLEN
      *lines,@buffer = @buffer.split NEWLINE,-1
      lines.map do |line|
        message = Message.parse line
        @receiver.call(message){|reply|send(reply)} if @receiver
        message
      end
    end
    def send(msg)
      @probe.call msg if @probe
      @socket.write msg.linecrlf
      @socket.flush
    end
  end
end
