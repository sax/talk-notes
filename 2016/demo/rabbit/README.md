## Usage

In parent directory:

```bash
bundle exec foreman
```

In current directory, in separate windows:

```bash
bundle exec ruby producer.rb
bundle exec ruby consumer/consumer.rb
```

```bash
bundle exec ruby producer.rb
bundle exec ruby consumer/consumer_with_sidekiq.rb
bundle exec sidekiq -C config/sidekiq.yml -r ./consumer/worker.rb
```
