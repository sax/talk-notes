require 'sidekiq'

class MyWorker
  include Sidekiq::Worker

  def self.handle_lapine_payload(payload, _metadata)
    perform_async(payload)
  end

  def perform(payload)
    puts "received message from sidekiq: #{payload}"
  end
end
