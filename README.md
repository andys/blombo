## Blombo

Treat redis-server like a deep ruby hash.


## Example usage

```ruby
  Blombo.redis = Redis.new
  $blombo = Blombo.new('ServerApp')

  $blombo.servers.status['web1'] = 'ok'
  $blombo.servers.status['web2'] = 'down'

  $blombo.servers.status[:web1]
  #=> "ok" 

  $blombo.servers.status[:web3]
  #=> nil 
```

This creates a Redis Hash with the key 'blombo:ServerApp:servers:status', and two fields ('web1', 'web2'), with two associated values.

You can store any Ruby objects as values, they will be automaticallly Marshalled.  (Strings are stored as-is).  Blombo does not cache anything but goes back to redis to get data whenever it is requested with a lookup[key].

Ruby's Enumerable is included along with each() so you can enjoy the usual range of ruby hash methods:

```ruby
  $blombo.server.status
  #=> #<Blombo:0x9ab0d84 @name="ServerApp:server:status" ...>

  $blombo.servers.status.exists
  => true 

  $blombo.servers.status.keys
  #=> ['web1', 'web2']

  $blombo.servers.status.type
  #=> 'hash'  

  $blombo.servers.status.select {|server, status| status == 'ok' }
  #=> [["web1", "ok"]] 
```

Blombo only saves the object back into redis if the []= method is used. Assignment must always be used to save to db.  This means you should maintain ruby objects carefully:

```ruby
  $blombo[:servers] = {:name => 'web1'}
  $blombo[:servers].merge!(:ip => '10.0.0.1')
  $blombo[:servers]  # => {:name=>"web1"}   # oops
```

## Redis List types

Treat blombo like an array and it'll marshal data to a redis list type.

```ruby
  $blombo.servers = [1,2]
  $blombo.servers << 3
  $blombo.servers.shift   # => 1
  $blombo.servers.last    # => 3
```

## Other Redis types

What if I need a specific redis command?  Thats OK - Blombo passes through redis commands curried with the key as the first parameter:

This:    $blombo.joblist.rpush('job1')
Equals:  $redis.rpush('blombo:ServerApp:joblist', 'job1')

Then I can pop it off the list:

```ruby
  $blombo.joblist.type
  #=> "list" 

  $blombo.joblist.llen
  #=> 1 

  $blombo.joblist.lpop
  #=> "job1" 
```

## Contact the author

Andrew Snow <andrew@modulus.org>
Andys^ on irc.freenode.net


Blombo never forgets.
