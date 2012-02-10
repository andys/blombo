require "#{File.dirname(__FILE__)}/../lib/blombo"
require 'test/unit'
require 'redis'
require "#{File.dirname(__FILE__)}/test_helper"

class TestBlombo < Test::Unit::TestCase
  def setup
    $redis.flushdb
    Blombo.redis = $redis
    @blombo = Blombo.new('test')
    @blombo[:flibble] = "test123"
    @blombo['derp'] = 'test321'
    @blombo.deep[:firstname] = 'Herp'
    @blombo.deep[:lastname] = 'Derpington'
  end
  
  def test_defined
    assert_equal false, @blombo.defined?('foo')
  end
  
  def test_undefined_redis_type
    assert_nil @blombo.foo.type
  end
  
  def test_empty_hash_lookup
    assert_nil @blombo['foo']
  end
  
  def test_hash_type
    assert_equal 'hash', @blombo.type
  end
  
  def test_hash_setter
    assert_equal({'flibble' => 'test123', 'derp' => 'test321'}, $redis.hgetall('blombo:test'))
  end

  def test_values
    assert_equal(['test123', 'test321'], @blombo.values.sort)
  end

  def test_keys
    assert_equal(['derp', 'flibble'], @blombo.keys.sort)
  end
  
  def test_each
    # Blombo includes Enumerable so we can test #each with #inject
    result = @blombo.inject({}) {|hsh, keyval| hsh.merge!(keyval.first => keyval.last) }
    assert_equal($redis.hgetall('blombo:test'), result)
  end
  
  def test_deep_empty_type
    assert Blombo===@blombo.deep
  end
  
  def test_deep_empty_array
    assert_equal [], @blombo.empty.to_a
  end
  
  def test_deep_empty_method
    assert_equal true, @blombo.empty.empty?
    assert_equal false, @blombo.deep.empty?
  end
  
  def test_deep_empty_hash_lookup
    assert_nil @blombo.deep['foo']
  end
  
  def test_redis_keys
    assert_equal(['blombo:test', 'blombo:test:deep'], $redis.keys.sort)
  end
  
  def test_deep_hash_setter
    assert_equal({'firstname' => 'Herp', 'lastname' => 'Derpington'}, $redis.hgetall('blombo:test:deep'))
  end

  def test_deeper_hash
    @blombo.a.b.c['d'] = 'e'
    assert_equal({'d' => 'e'}, $redis.hgetall('blombo:test:a:b:c'))
    assert_equal [@blombo.a.b.c], @blombo.a.blombo_children
  end

  def test_marshal
    @blombo.marshaltest[:number] = 12345
    @blombo.marshaltest[:nil] = nil
    assert_equal 12345, @blombo.marshaltest[:number]
    assert_equal nil, @blombo.marshaltest[:nil]
  end
  
  def test_redis_ops
    @blombo.listy.rpush('job1')
    @blombo.listy.rpush('job2')
    assert_equal 2, $redis.llen('blombo:test:listy')
    assert_equal ['job1', 'job2'], @blombo.listy.lrange(0, -1)
  end
  
  def test_redis_list_type
    @blombo.listy.rpush('job1')
    assert_equal 'list', @blombo.listy.type
  end
  
end
