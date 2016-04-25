Decoupling Ruby Applications with RabbitMQ
==========================================

As a software project grows, so does its complexity. Micro-services are all the
rage for breaking up code into smaller, more manageable pieces. But how does one
iterate to a micro-service architecture? How does one keep code not only distributed,
but decoupled? In this talk I'll explain how a message bus can be used to facilitate
not only service communication, but service development. I'll focus on RabbitMQ,
though the opinions presented can be applied to other technologies.


## Who am I?

* Eric Saxby
* Wide range of jobs, both computer related and not
  * I usually say that my first job out of university was doing Flash development
    after learning Flash in a weekend
  * This is wrong. My first job was actually as an usher for a circus. This is
    both a literal fact, and a description of my second job, doing Flash
    development.
  * I have done things that could be called software development for 20 years,
    but have only been a full time programmer for 8
* Most of the work that taught me about this subject was done at ModCloth and Wanelo
* I am currently doing consulting at Pivotal on CloudFoundry


## What is a message bus?

* A bucket into which messages generated by one application can be sent
* Other application can choose to listen for specific types of messages,
  based on some metadata attached to each message


## Let us look closer

* The application producing a message knows about the bucket, and it knows
  about the message
* The application consuming the message knows about the bucket, and it knows
  about the message
* The producer and the consumer do not know about each other
* Multiple consumers can listen for the same message, without requiring changes
  to the producer


## Why would I want to use a message bus?

* Create and deploy multiple applications that communicate with each other
* An application produces events that other applications care about
  * But where the event producer does not need to know about the other
    applications
* Want to break an application into smaller bits
  * An application might be getting too big (arbitrary definition)
  * Some logic is not intrinsic to the purpose of the application, and can be
    done outside of the request cycle, outside of the customer-facing business
    logic
* Need to introduce new business rules, new features, but you realize that your
  current application(s) don't care about it
* You want to start consuming events from somewhere else, but don't want to
  code all of the data translation, data fixes and weird authentication schemes
  into your website app
* You want to be able to deploy multiple apps without them dropping messages
* You have functionality that can be (or needs to be) scaled entirely differently
  than everything else
* You have components that require different availability than others


## Common confusion

* A bucket into which messages generated by one application can be sent
* Other application can choose to listen for specific types of messages,
  as determined by some metadata attached to each message

* If you're like me (or many people I have worked with), then despite the
  simplicity of that definition, as soon as you start to read documentation,
  you will jump to conclusions about implementations that will cause you
  problems later
* Might be helpful to talk about common tools and patterns that are often
  confused with a message bus


## What is not a message bus?

* RPC
  * for the purposes of this talk, I'm lumping chained HTTP requests into RPC
  * because I assume one would write a client such that the caller does not care
    that it is HTTP (see hexagonal architecture)
* Background jobs


## RPC

* An event happens in Application A (ie. web request)
* The event is not *complete* unless Application B is told about the event

* Application A sends a message to Application B
* Application B responds to say that it was successful


## Why is this not a message bus?

* The client knows the address of the server
* The server needs to be available
* For N services, N need to be available
  * Client must implement retry logic
  * Client must understand (some) errors


## Background jobs

* For Ruby:
  * delayed_job, resque, sidekiq
* Used when work should be done outside of a web request
* Used when an application is not a web application
* Daemon starts up independently
  * connects to a persistent data store (mysql, postgres, redis)
  * pulls messages from a queue
  * dispatches each message to a specific class based on metadata in the message


## Why is this not a message bus?

* Application produces messages
* Consumer does work on messages based on metadata

Consumer:

```
class Worker
  include Sidekiq::Worker

  def perform(message)
    puts message
  end
end
```

Producer:

```
class MyController < ApplicationController
  def create
    Worker.perform_async(params.to_s)
  end
end
```

* The message producer has explicit knowledge of the consumer
* Multiple consumers require multiple messages


## What is a message bus?

* Many technologies can be used
  * RabbitMQ
  * Kafka
  * Amazon SNS


## RabbitMQ

* AMQP protocol
  * Advanced Message Queuing Protocol
* Broker
  * Primary, Replicas, failover
* Exchange
  * A place that producers can publish messages to
  * A place that consumers can register queues in
* Queue
  * Registers a binding that matches some messages
  * When a message is matched, it is copied into a queue
  * Can be defined as `durable: true`, in which case messages are written to disk
* Binding
  * Rules used by exchanges to route messages
* Message
  * Arbitrary payload
  * Includes a routing key in its metadata
    * some.arbitrary.routing.key


## Exchange types

* Direct
* Fanout
* Topic


## Direct exchange

* When queue binds, it includes a routing key K
* If a message has routing key R, and R == K, then exchange routes it to queue
* Each application can register a queue with a different routing key
* Producer can target message to specific application by using the correct key
* Used where a tool like Sidekiq would be used


## Problems with Direct exchanges

* Producer must know about consumers
* In order to target multiple consumers, duplicate messages with different
  routing keys must be written
* Adding a consumer application requires changing the producer application


## Fanout exchange

* Each message is written to every queue
* Routing keys are ignored
* Useful when many applications care about the same message
* Producer does not know about the consumers


## Problems with Fanout exchanges

* If a queue exists for a consumer, every message will be delivered to the consumer
  even if it does not care about the specific message
* If a consumer does not care about every message, introduces a lot of
  unnecessary work


## Topic exchange

* Queue is bound with a routing key pattern
  * some.arbitrary.routing.* -- match a single word
  * some.arbitrary.# -- matching 0 or more words
* Message is routed to every queue that matches its routing key
* Messages that are not matched are dropped (*)
  (*) or returned to the publisher


## Yay topic exchanges!

* Producer does not know about consumers
* Consumers can listen for specific messages
* Adding new messages is cheap, because if no bindings match the message is discarded


## Message lifecycle

* Producer writes a new message to an exchange
  * Depending on configuration, producer might wait for an acknowledgement
* Exchange sees bindings, writes message into 0 or more queue
* Queue pushes message to a waiting consumer
* Consumer acknowledges message

* Producer can also wait for a consumer acknowledgment
  * You're in a large distributed system. Why would you do this?


## Resource utilization

* Messages in queues require RAM
* When queues are durable, the more places a queue is written, the greater the
  disk I/O

* Don't let queue depth back up
* Scale disk I/O by scaling number of brokers


## Scaling and availability

* Brokers can exist in a cluster
  * Exchanges and bindings are everywhere
  * Queues exist in a single node by default
* Queues can optionally be mirrored
  * One node serves as a primary
  * Other mirrors serve as replicas
  * When the primary disappears, the oldest replica is promoted
  * When a new mirror joins, it only receives new messages
* Any node can receive operations, which happen on the primary


## Or...

* Pretend that all RabbitMQ nodes are independent
* Put HAProxy/ELB in front of all nodes

* Producers connect over TCP
  * TCP connections are long-lived in HAProxy
  * When a broker goes down, producer can re-connect, going to another broker

* Need to ensure that each broker has consumers from each application


## Don't let queue depth back up

* RabbitMQ can be combined with another tool, such as Sidekiq or Resque
* Consumer receives message, route it to the correct application-
  specific code using Sidekiq or Resque, then acknowledge it
* Do as little work in the RabbitMQ consumer daemon as possible
* Allows you to scale application resources separately from your message bus
  resources
* If queues still back up, you may be generating more messages than a single
  (evented) Ruby process can handle. Run another process.


## What do we have in Ruby?

* amqp gem
  * eventmachine
* bunny gem
  * not eventmachine

* amqp gem is great for standalone daemons or as a part of other daemons
  based on eventmachine
* amqp gem is not great for running in non-eventmachine applications
  * unicorn, puma, other web server daemons

* bunny is great for producing messages
* amqp is great for consuming messages


## Demo



## What can go wrong?

Nothing!
jk


## Availability

* Once this infrastructure is used, it needs to be available
* When RabbitMQ backs up or goes down, you are in a bad place

* Better focusing attention on one highly available component than on making
  everything redundant and resilient


## Be careful about pattern matching

* Don't use `*` when you mean `#`
* If you have ever used computers before, you might accidentally use `*`
  instead of `#`
* Double check routing keys before deploying producers or consumers


## Think about routing keys

* Grammar is confusing if it is inconsistent
  * `thing.create`
  * `things.create`
  * `things.created`
  * `thing.created`
  * `thingie.crate`
* When routing keys are generated based on external resources, they may not be
  consistent with your other keys, or even between their own keys
  * Receiving webhooks from external parties


## Think about naming exchanges and queues

* `my.topic` exchange
* `product.related.action` routing key
  * specific to payload of message
* `application.product.action` queue name
  * seeing the application name helps with debugging backed up queues


## Queue properties are confusing to change after the fact

* Properties are set at queue creation
* Most properties cannot be changed after the fact
* In many cases, daemons will connect with no errors, even if property definitions
  change

For example:

* Create a queue with `durability: false`
* Connect to the same queue, specifying `durability: true`
* Everything will work fine, but the queue is not durable

* Changing names or properties requires creating new queues, bindings, then
  deleting the old queues


## Queues don't delete themselves

* If an application goes away, its queues may stay
* Queues with bindings may continue to receive messages


