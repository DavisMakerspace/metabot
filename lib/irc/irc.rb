module IRC
  MAXLEN = 512
  NEWLINE = "\r\n"
  class Message
    def initialize(line, prefix, cmd, *params)
      @line = line
      @prefix = prefix
      @cmd = cmd
      @params = params
      @overrun = @line.size > MAXLEN ? MAXLEN-@line.size : 0
      @reply = Integer(@cmd) rescue nil
    end
    attr_reader :line, :prefix, :cmd, :params, :overrun, :reply
    def self.parse(line)
      line.chomp! NEWLINE
      prefix,_,body = line[0] == ':' ? line[1..-1].partition(' ') : [nil,nil,line]
      body,_,trailing = body.partition(' :')
      cmd,*params = body.split
      params.push trailing if trailing
      Message.new line, prefix, cmd, *params
    end
    def self.command(cmd, *params, prefix:nil)
      cmd, *params = [cmd,*params].map{|arg|arg.to_s}
      *params,trailing = params
      if trailing
        trailing = ':'+trailing if trailing.include? ' '
        params.push trailing
      end
      line = "#{prefix ? ':'+prefix+' ' : ''}#{cmd}#{params.map{|p|' '+p}.join}"
      Message.new line, prefix, cmd, *params
    end
    def linecrlf; @line + NEWLINE; end
    def ping?; @cmd == 'PING'; end
    def reply?; !!@reply; end
    def server_reply?; (0..99).include? @reply; end
    def command_reply?; (200..399).include? @reply; end
    def error_reply?; (400..599).include? @reply; end
    def target; @params.first; end
    def nickname; @prefix && @prefix.include?('!') ? @prefix.split('!').first : nil; end
  end
  class Client
    def initialize(socket)
      @socket = socket
      @receiver = nil
      @probe = nil
      @buffer = ''
    end
    attr_reader :receiver, :probe
    def new_receiver(klass, *args, **opts)
      @receiver = klass ? (opts.empty? ? klass.new(self,*args) : klass.new(self,*args,**opts)) : nil
    end
    def new_probe(klass, *args, **opts)
      @probe = klass ? (opts.empty? ? klass.new(self,*args) : klass.new(self,*args,**opts)) : nil
    end
    def to_io; @socket; end
    def read_nonblock
      @buffer += @socket.read_nonblock(MAXLEN)
      *lines,@buffer = @buffer.split(NEWLINE,-1)
      lines.map do |line|
        message = Message.parse line
        @receiver.call message if @receiver
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
