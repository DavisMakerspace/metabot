module IRC
  ERR_NICKNAMEINUSE = 433
  class DebugLog
    def initialize(client, log=Logger.new(STDERR), level:Logger::DEBUG, progname:nil)
      @client = client
      @log = log
      @level = level
      @progname = progname
    end
    def call(msg); @log.add(@level,nil,@progname){msg.line}; end
  end
  class Init
    def initialize(client, nickname, username, realname, mode:0, password:nil, channels:nil)
      @client = client
      @nickname = nickname
      @username = username
      @realname = realname
      @mode = mode
      @password = password
      @channels = channels
      @state = :init
    end
    def call(msg)
      case @state
      when :init
        @client.send IRC::Message.command 'PASS', @password if @password
        @client.send IRC::Message.command 'USER', @username, @mode, '*', @realname
        @client.send IRC::Message.command 'NICK', @nickname
        @state = :pending
      when :pending
        if msg.reply == ERR_NICKNAMEINUSE
          base,number,_ = msg.params[1].partition /[0-9]*$/
          number = Integer(number)+1 rescue 2
          @client.send IRC::Message.command 'NICK', base+number.to_s
        elsif msg.reply? && !msg.error_reply?
          @client.send IRC::Message.command 'JOIN', @channels.join(',') if @channels
          @state = :done
        end
      end
    end
  end
  class Pong
    def initialize(client); @client=client; end
    def call(msg); @client.send IRC::Message.command('PONG',msg.params.first) if msg.ping?; end
  end
  class Nick
    def initialize(client, nickname)
      @client = client
      @nickname = nickname
      @state = :check
    end
    def call(msg)
      case @state
      when :check
        if (msg.server_reply? || msg.command_reply? || msg.cmd == 'NICK')
          @state = msg.target != @nickname ? :taken : :done
        elsif msg.reply == ERR_NICKNAMEINUSE
          @state = :taken
        end
      when :taken
        if msg.ping?
          @client.send IRC::Message.command 'NICK', @nickname
          @state = :check
        end
      end
    end
  end
end
