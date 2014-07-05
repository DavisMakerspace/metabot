module LineIO
  READSIZE = 1024
  NEWLINE = "\n"
  class Client
    def initialize(socket, newline:NEWLINE, readsize:READSIZE)
      @socket = socket
      @newline = NEWLINE
      @readsize = readsize
      @buffer = ""
      @receiver = nil
      @probe = nil
    end
    attr_accessor :receiver, :probe
    def to_io; @socket; end
    def eof?; !@buffer; end
    def receive
      begin
        @buffer += @socket.read_nonblock @readsize
      rescue EOFError
        @buffer = nil
        @receiver.call nil if @receiver
        nil
      else
        *lines,@buffer = @buffer.split @newline,-1
        lines.each{|line|@receiver.call(line){|reply|send(reply)}} if @receiver
        lines
      end
    end
    def send(line)
      length = @socket.write line
      length += @socket.write @newline
      @socket.flush
      @probe.call line if @probe
      length
    end
  end
  class Server
    def initialize(server, newline:NEWLINE, readsize:READSIZE)
      @server = server
      @newline = newline
      @readsize = readsize
      @clients = []
      @receiver = nil
    end
    attr_accessor :receiver
    def to_io; @server; end
    def sockets; @clients.reject!{|c|c.eof?}; [self, *@clients]; end
    def receive
      @clients.push Client.new @server.accept, newline:@newline, readsize:@readsize
      @receiver.call @clients.last if @receiver
      @clients.last
    end
  end
end
