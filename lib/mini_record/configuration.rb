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
    attr_accessor :destructive, :raise_on_destructive_change_needed, :table_whitelist

    def initialize
      @destructive = true
      @raise_on_destructive_change_needed = false
      @table_whitelist = []
    end
  end
end
