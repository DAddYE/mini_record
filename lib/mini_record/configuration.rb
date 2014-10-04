module MiniRecord
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :destructive

    def initialize
      @destructive = true
    end
  end
end