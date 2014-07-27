require 'logger'
module Receiver
  class DebugLog
    def initialize(log=Logger.new(STDERR), level:Logger::DEBUG, progname:nil, to_s:->(msg){msg.to_s})
      @log = log
      @level = level
      @progname = progname
      @to_s = to_s
    end
    def call(msg); @log.add(@level,nil,@progname){@to_s.call(msg)}; end
  end
  class Multi
    def initialize
      @receivers = []
    end
    attr_reader :receivers
    def call(msg)
      @receivers.each{|receiver|receiver.call(msg){|reply|yield reply}}
    end
  end
end
