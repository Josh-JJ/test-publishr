module Publishr
  def self.log(text)
    if defined?(ActiveRecord)
      ActiveRecord::Base.logger.info text
    else
      puts text
    end
  end
end