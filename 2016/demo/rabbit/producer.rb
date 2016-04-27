require 'bunny'

Signal.trap('INT') { exit }

conn = Bunny.new(vhost: '/demo', user: 'demo', password: 'guest')
conn.start

channel = conn.create_channel

exchange = Bunny::Exchange.new(channel, 'topic', 'rabbit.topic', durable: true)

while true
  message = "hello!"
  routing_key = "hello.world"
  other_routing_key = "hello.blah"

  puts "publishing message: #{message}, routing_key: #{routing_key}"
  exchange.publish(message, routing_key: routing_key)

  puts "publishing message: #{message}, routing_key: #{other_routing_key}"
  exchange.publish(message, routing_key: other_routing_key)

  sleep 1
end
