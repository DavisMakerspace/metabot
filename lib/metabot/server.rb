module MetaBot
  PREFIX = '!'
  class Server
    def initialize(server, ircsocket, nickname, username, realname, channel, formatter:nil, logger:Logger.new(STDERR), prefix:PREFIX)
      @server = LineIO::Server.new server
      @channel = channel
      @formatter = formatter || ->(msg,tag){ tag ? "#{tag} | #{msg}" : msg }
      @prefix = prefix
      @realname = realname
      @irc = IRC::Client.new ircsocket
      @irc.probe = Receiver::DebugLog.new logger, progname:'irc-send' if logger
      @irc.receiver = Receiver::Multi.new
      @irc.receiver.receivers.push Receiver::DebugLog.new logger, progname:'irc-recv' if logger
      @irc.receiver.receivers.push IRC::Init.new nickname, username, realname, channels:[channel]
      @irc.receiver.receivers.push IRC::Nick.new nickname
      @irc.receiver.receivers.push IRC::Pong.new
      @irc.receiver.receivers.push IRCClient.new channel, @prefix
      @ircclient = @irc.receiver.receivers.last
      @clients = {}
      @server.receiver = ->(client) do
        client.probe = Receiver::DebugLog.new logger, progname:"client-#{client.object_id}-send" if logger
        client.receiver = Receiver::Multi.new
        client.receiver.receivers.push Receiver::DebugLog.new logger, progname:"client-#{client.object_id}-recv" if logger
        client.receiver.receivers.push MetaBot::Client.new
        @clients[client.receiver.receivers.last] = client
      end
    end
    def send_irc(msg, tag=nil)
      @irc.send IRC::Message.command 'PRIVMSG', @channel, @formatter.call(msg, tag)
    end
    def handle_irccmd(cmd)
      case cmd.command
      when '' then send_irc "#{@realname} [#{@prefix}? to show available commands]"
      when '?'
        cmds = @clients.keys.flat_map{|c|c.irccmds||[]}
        cmds = cmds.empty? ? 'No commands available' : "commands: #{cmds.join ' '}"
        send_irc cmds
      end
    end
    def run
      loop do
        rs,_ = IO.select [*@server.sockets,@irc]
        rs.each{|s|s.receive}
        @clients.keys.each{|c|c.queue.each{|m|send_irc(m,c.name)};c.queue.clear}
        @clients.reject!{|c|c.finished?}
        @ircclient.queue.each do |cmd|
          if ! handle_irccmd cmd
            handlers = @clients.select{|c,_| c.irccmds.include? cmd.command}
            handlers.each{|c,cio| cio.send c.handle_irccmd cmd}
            send_irc('Unknown command') if handlers.empty?
          end
        end
        @ircclient.queue.clear
      end
    end
  end
end
