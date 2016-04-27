require 'amqp'
require 'pry'

Signal.trap('INT') { EventMachine.stop }
Signal.trap('TERM') { $STOP_CONSUMER = true }

def should_exit?
  $STOP_CONSUMER
end

EventMachine.run do
  puts "Starting EventMachine"
  conn = AMQP.connect(host: '127.0.0.1', username: 'demo', password: 'guest', ssl: false, vhost: '/demo')
  channel = AMQP::Channel.new(conn)
  exchange = AMQP::Exchange.new(channel, :topic, 'rabbit.topic', durable: true)

  queue = channel.queue('consumer.hello.world', durable: true).
    bind(exchange, routing_key: 'hello.world')

  queue.subscribe(ack: true) do |metadata, payload|
    puts "received message: #{payload}, routing_key: #{metadata.routing_key}"
    metadata.ack
  end

  EventMachine.add_periodic_timer(1) do
    if should_exit?
      puts "Stopping EventMachine"
      EventMachine.stop_event_loop
    end
  end
end
