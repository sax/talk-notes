require 'lapine'
require 'pry'

Lapine.add_connection 'lapine-conn', {
  host: '127.0.0.1',
  port: 5672,
  user: 'demo',
  password: 'guest',
  heartbeat: 30
}

Lapine.add_exchange 'lapine.topic',
  durable: true,
  connection: 'lapine-conn',
  type: 'topic'


class Publisher
  include Lapine::Publisher

  exchange 'lapine.topic'

  def initialize(message)
    @message = message
  end

  def to_hash
    {
      'message' => message
    }
  end
end

binding.pry
