
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

  
  def defined?(key)
    redis.exists(key.to_s)
  end

  def nil?
    empty?
  end
  
  def empty?
    redis.hlen(blombo_key) == 0
  end

  def to_hash
    keys.inject({}) {|h,k| h.merge!(k => self[k]) }
  end

  def each(*args, &bl)
    if(type == 'list')
      lrange(0, -1).map {|va| each(*args, &bl) }
    else
      to_hash.each(*args, &bl)
    end
  end

  def to_a
    if(type == 'list')
      lrange(0, -1).map {|val| self.class.from_redis_val(val) }
    else
      to_hash.to_a
    end
  end

  def keys
    hkeys
  end

  def values
    hvals.map {|v| self.class.from_redis_val(v) }
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
      key(meth)
    elsif params.length == 1 && meth =~ /^(.*)=$/
      if Hash === params[0]
        key($1).del
        params[0].each {|k,val| key($1)[k] = val }
      elsif Enumerable === params[0]
        key($1).del
        params[0].each {|val| key($1).push(val) }
      else
        raise TypeError.new('Blombo setters must be sent a Hash or Array')
      end
    else
      super(meth, *params, &bl)
    end
  end
  
  def key(*args)
    Blombo.new("#{@name}:#{args.join(':')}", self)
  end

  def blombo_children
    blombo_children_names.map {|k| Blombo.new(k, self) }
  end

  def blombo_children_names
    self.class.redis.keys("#{blombo_key}:*").map {|k| k.gsub(/^blombo:/,'') }
  end
  
  
  def <<(x)
    push(x)
  end
  
  def push(*x)
    rpush(*(x.map {|val| self.class.to_redis_val(val) }))
  end
  
  def unshift(*x)
    lpush(*(x.map {|val| self.class.to_redis_val(val) }))
  end
  
  def first
    if type == 'list'
      self[0]
    elsif(k = keys.first)
      [k, self[k]]
    end
  end  

  def last
    if type == 'list'
      self[-1]
    elsif(k = keys.last)
      [k, self[k]]
    end
  end  
  
  def length
    llen
  end
  
  def []=(key, val)
    if type == 'list'
      lset(key.to_i, self.class.to_redis_val(val))
    else
      hset(key.to_s, self.class.to_redis_val(val))
    end
  end

  def [](key)
    val = if(type == 'list')
      lindex(key.to_i)
    else
      hget(key.to_s)
    end
    self.class.from_redis_val(val) if val
  end

  def shift
    val = lpop
    self.class.from_redis_val(val) if val
  end

  def pop
    val = rpop
    self.class.from_redis_val(val) if val
  end
  
  def to_s
    "#<#{blombo_key}>"
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
