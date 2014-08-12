module MetaBot
  PREFIX = '!'
  QPREFIX = '?'
  class Server
    def initialize(server, ircsocket, nickname, username, realname, channel, formatter:nil, logger:Logger.new(STDERR), prefix:PREFIX, qprefix:QPREFIX)
      @server = LineIO::Server.new server
      @channel = channel
      @formatter = formatter || ->(msg,tag){ tag ? "[#{tag}] #{msg}" : msg }
      @prefix = prefix
      @qprefix = qprefix
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
      when '' then send_irc "#{@realname} [#{@prefix}#{@qprefix} shows available commands; #{@prefix}#{@qprefix} cmd to describe command cmd]"
      when @qprefix
        if cmd.arg.empty?
          cmds = @clients.keys.flat_map{|c|c.irccmds.keys||[]}
          cmds = cmds.empty? ? 'no commands available' : "commands: #{cmds.join ' '}"
          send_irc cmds
        else
          client, _ = @clients.find{|c,_| c.irccmds.include? cmd.arg}
          if client
            send_irc "#{cmd.arg}: #{client.irccmds[cmd.arg]}"
          else
            send_irc 'unknown command'
          end
        end
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
            client, client_io = @clients.find{|c,_| c.irccmds.include? cmd.command}
            if client
              client_io.send client.handle_irccmd cmd
            else
              send_irc 'unknown command'
            end
          end
        end
        @ircclient.queue.clear
      end
    end
  end
end
