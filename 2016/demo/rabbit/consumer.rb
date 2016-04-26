require 'amqp'

EventMachine.run do
  conn = AMQP.connect(host: '127.0.0.1', username: 'demo', password: 'guest', ssl: false, vhost: '/demo')
  channel = AMQP::Channel.new(conn)
  exchange = AMQP::Exchange.new(channel, :topic, 'demo.topic', durable: true)

  queue = channel.queue('consumer.hello.world', durable: true).
    bind(exchange, routing_key: 'hello.world')

  queue.subscribe(ack: true) do |metadata, payload|
    puts "received message: #{payload}, metadata: #{metadata.inspect}"
    metadata.ack
  end
end
