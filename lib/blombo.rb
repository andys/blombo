
class Blombo
  
  include Enumerable
  include Comparable
  attr_reader :blombo_parent

  class << self
    attr_writer :redis
    def redis
      Thread.current[:blombo_redis] ||= Redis.new(Hash[*([
        :path, :host, :port, :db, :timeout, :password, :logger
      ].map {|f| [f, @redis.client.send(f)] }.flatten)])
    end

    def is_marshalled?(str)
      Marshal.dump(nil)[0,2] == str[0,2] # Marshall stores its version info in first 2 bytes
    end
    def to_redis_val(obj)
      if Integer===obj || String===obj && obj !~ /^\d+$/ && !is_marshalled?(obj)
        obj.to_s
      else
        Marshal.dump(obj)
      end
    end
    def from_redis_val(str)
      if(is_marshalled?(str))
        Marshal.load(str)
      elsif(str =~ /^\d+$/)
        str.to_i
      else
        str
      end
    end
    def [](name)
      new(name)
    end
    def method_missing(meth, *params, &bl)
      if params.empty? && meth =~ /^[a-z_][a-z0-9_]*$/i
        new meth
      else
        super
      end
    end

  end
  
  def redis
    self.class.redis
  end

  def initialize(name, blombo_parent=nil)
    @name = name.to_s
    @blombo_parent = blombo_parent
  end
  
  def with_timeout(secs)
    begin
      Timeout.timeout(secs) do
        yield(self)
      end
    rescue Timeout::Error
      false
    end
  end

  def <=>(other)
    @name <=> other.blombo_name
  end

  def blombo_key
    "blombo:#{@name}"
  end
  
  def blombo_name
    @name
  end

  def []=(key, val)
    redis.hset(blombo_key, key.to_s, self.class.to_redis_val(val))
  end
  
  def defined?(key)
    redis.exists(key.to_s)
  end

  def [](key)
    if(val = redis.hget(blombo_key, key.to_s))
      self.class.from_redis_val(val)
    end
  end

  def nil?
    empty?
  end
  
  def empty?
    redis.hlen(blombo_key) == 0
  end

  def to_hash
    redis.hgetall(blombo_key)
  end

  def each(*args, &bl)
    to_hash.each(*args, &bl)
  end

  def to_a
    redis.hgetall(blombo_key).to_a
  end

  def keys
    self.class.redis.hkeys(blombo_key)
  end

  def values
    self.class.redis.hvals(blombo_key).map {|v| self.class.from_redis_val(v) }
  end
  
  def clear
    redis.del(blombo_key)
  end
  
  def type
    @type ||= (t = Blombo.redis.type(blombo_key)) && t != 'none' && t || nil
  end

  def method_missing(meth, *params, &bl)
    if Blombo.redis.respond_to?(meth)
      Blombo.redis.send(meth, blombo_key, *params, &bl)
    elsif params.empty? && meth =~ /^[a-z_][a-z0-9_]*$/i
      Blombo.new("#{@name}:#{meth}", self)
    else
      super(meth, *params, &bl)
    end
  end

  def blombo_children
    self.class.redis.keys("#{blombo_key}:*").map {|k| Blombo.new(k.gsub(/^blombo:/,''), self) }
  end
  
end


=begin

blombo = Blombo.new(redis server details)



blombo.blah = {'hello' => 'world'}
blombo.blah = OpenStruct(..)
blombo.blah = activerecord model

May as well assign each object a uniq id (using redis counters?)
to allow referencing / assocations


=end
