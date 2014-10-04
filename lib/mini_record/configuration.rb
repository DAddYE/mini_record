module MiniRecord
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.reset_configuration!
    self.configuration = Configuration.new
  end
  
  class Configuration
    attr_accessor :destructive

    def initialize
      @destructive = true
    end
  end
end