module MetaBot
  IRCCommand = Struct.new(:target, :nickname, :command, :arg)
  class IRCClient
    def initialize(channel, prefix)
      @channel = channel
      @prefix = prefix
      @queue = []
    end
    attr_reader :queue
    def call(msg)
      if msg.cmd == 'PRIVMSG' && msg.nickname && msg.target == @channel && msg.params.last[0] == @prefix
        cmd,_,arg = msg.params.last[1..-1].partition ' '
        @queue.push IRCCommand.new msg.target, msg.nickname, cmd, arg
      end
    end
  end
end
