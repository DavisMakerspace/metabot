module MetaBot
  class Client
    def initialize
      @name = nil
      @irccmds = []
      @queue = []
      @locked = false
      @finished = false
    end
    attr_reader :name, :queue, :irccmds
    def finished?; !!@finished; end
    def cmd_name(name)
      return 'ERROR :locked' if @locked
      @name = name
      'OK'
    end
    def cmd_cmds(*irccmds)
      @irccmds = irccmds
      'OK'
    end
    def cmd_lock
      @locked = true
      'OK'
    end
    def cmd_send(msg)
      return 'ERROR :no name' if !@name
      @queue << msg
      'OK'
    end
    def handle_cmd(cmd, *args)
      cmd = 'cmd_'+cmd.downcase
      if respond_to? cmd
        begin
          send cmd, *args
        rescue ArgumentError => e
          "ERROR :#{e}"
        end
      else
        'ERROR :unknown command'
      end
    end
    def call(msg)
      (@finished=true;return) if !msg
      return if msg.empty?
      cmdargs,sep,more = msg.partition ' :'
      cmd,*args = cmdargs.split
      args.push more if !sep.empty?
      yield handle_cmd cmd, *args
    end
    def handle_irccmd(irccmd)
      "CMD #{irccmd.command.downcase} #{irccmd.nickname} :#{irccmd.arg}"
    end
  end
end
