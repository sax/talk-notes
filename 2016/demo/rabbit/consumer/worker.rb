require 'sidekiq'

class Worker
  include Sidekiq::Worker

  def perform(payload)
    puts "received message from sidekiq: #{payload}"
  end
end
