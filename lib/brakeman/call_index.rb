require 'set'

class Brakeman::CallIndex
  def initialize calls
    @calls_by_method = Hash.new { |h,k| h[k] = [] }
    @calls_by_target = Hash.new { |h,k| h[k] = [] }
    @methods = Set.new
    @targets = Set.new

    index_calls calls
  end

  def find_calls options
    target = options[:target] || options[:targets]
    method = options[:method] || options[:methods]
    nested = options[:nested]
    
    if options[:chained]
      return find_chain options
    #Find by narrowest category
    elsif target and method and target.is_a? Array and method.is_a? Array
      if target.length > method.length
        calls = filter_by_target calls_by_methods(method), target
      else
        calls = calls_by_targets(target)
        calls = filter_by_method calls, method
      end

    #Find by target, then by methods, if provided
    elsif target
      calls = calls_by_target target

      if calls and method
        calls = filter_by_method calls, method
      end

    #Find calls with no explicit target
    #with either :target => nil or :target => false
    elsif options.key? :target and not target and method
      calls = calls_by_method method
      calls = filter_by_target calls, nil

    #Find calls by method
    elsif method
      calls = calls_by_method method
    else
      warn "Invalid arguments to CallCache#find_calls: #{options.inspect}"
    end

    return [] if calls.nil?

    #Remove calls that are actually targets of other calls
    #Unless those are explicitly desired
    calls = filter_nested calls unless nested

    calls
  end

  private

  def index_calls calls
    calls.each do |call|
      @methods << call[:method].to_s
      @targets << call[:target].to_s
      @calls_by_method[call[:method]] << call
      @calls_by_target[call[:target]] << call
    end
  end

  def find_chain options
    target = options[:target] || options[:targets]
    method = options[:method] || options[:methods]

    calls = calls_by_method method
    
    return [] if calls.nil?

    calls = filter_by_chain calls, target
  end

  def calls_by_target target
    if target.is_a? Array
      calls_by_targets target
    elsif target.is_a? Regexp
      targets = @targets.select do |t|
        t.match target
      end

      if targets.empty?
        []
      elsif targets.length > 1
        calls_by_targets targets
      else
        calls_by_target[targets.first]
      end
    else
      @calls_by_target[target]
    end
  end

  def calls_by_targets targets
    calls = []

    targets.each do |target|
      calls.concat @calls_by_target[target] if @calls_by_target.key? target
    end

    calls
  end

  def calls_by_method method
    if method.is_a? Array
      calls_by_methods method
    elsif method.is_a? Regexp
      methods = @methods.select do |m|
        m.match method
      end

      if methods.empty?
        []
      elsif methods.length > 1
        calls_by_methods methods
      else
        @calls_by_method[methods.first.to_sym]
      end
    else
      @calls_by_method[method.to_sym]
    end
  end

  def calls_by_methods methods
    methods = methods.map { |m| m.to_sym }
    calls = []

    methods.each do |method|
      calls.concat @calls_by_method[method] if @calls_by_method.key? method
    end

    calls
  end

  def calls_with_no_target
    @calls_by_target[nil]
  end

  def filter calls, key, value
    if value.is_a? Array
      values = Set.new value

      calls.select do |call|
        values.include? call[key]
      end
    elsif value.is_a? Regexp
      calls.select do |call|
        call[key].to_s.match value
      end
    else
      calls.select do |call|
        call[key] == value
      end
    end
  end

  def filter_by_method calls, method
    filter calls, :method, method
  end

  def filter_by_target calls, target
    filter calls, :target, target
  end

  def filter_nested calls
    filter calls, :nested, false
  end

  def filter_by_chain calls, target
    if target.is_a? Array
      targets = Set.new target

      calls.select do |call|
        targets.include? call[:chain].first
      end
    elsif target.is_a? Regexp
      calls.select do |call|
        call[:chain].first.to_s.match target
      end
    else
      calls.select do |call|
        call[:chain].first == target
      end
    end
  end
end