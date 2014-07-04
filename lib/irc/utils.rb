module IRC
  ERR_NICKNAMEINUSE = 433
  class Init
    def initialize(nickname, username, realname, mode:0, password:nil, channels:nil)
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
        yield IRC::Message.command 'PASS', @password if @password
        yield IRC::Message.command 'USER', @username, @mode, '*', @realname
        yield IRC::Message.command 'NICK', @nickname
        @state = :pending
      when :pending
        if msg.reply == ERR_NICKNAMEINUSE
          base,number,_ = msg.params[1].partition /[0-9]*$/
          number = Integer(number)+1 rescue 2
          yield IRC::Message.command 'NICK', base+number.to_s
        elsif msg.reply? && !msg.error_reply?
          yield IRC::Message.command 'JOIN', @channels.join(',') if @channels
          @state = :done
        end
      end
    end
  end
  class Pong
    def call(msg); yield IRC::Message.command('PONG',msg.params.first) if msg.ping?; end
  end
  class Nick
    def initialize(nickname)
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
          yield IRC::Message.command 'NICK', @nickname
          @state = :check
        end
      end
    end
  end
end
