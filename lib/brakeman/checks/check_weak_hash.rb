require 'brakeman/checks/base_check'

class Brakeman::CheckWeakHash < Brakeman::BaseCheck
  Brakeman::Checks.add_optional self

  @description = "Checks for use of weak hashes like MD5"

  DIGEST_CALLS = [:base64digest, :digest, :hexdigest, :new]

  def run_check
    tracker.find_call(:targets => [:'Digest::MD5', :'Digest::SHA1', :'OpenSSL::Digest::MD5', :'OpenSSL::Digest::SHA1'], :nested => true).each do |result|
      process_hash_result result
    end

    tracker.find_call(:target => :'Digest::HMAC', :methods => [:new, :hexdigest], :nested => true).each do |result|
      process_hmac_result result
    end

    tracker.find_call(:targets => [:'OpenSSL::Digest::Digest', :'OpenSSL::Digest'], :method => :new).each do |result|
      process_openssl_result result
    end
  end

  def process_hash_result result
    return if duplicate? result
    add_result result

    input = nil
    call = result[:call]

    if DIGEST_CALLS.include? call.method
      if input = user_input_as_arg?(call)
        confidence = CONFIDENCE[:high]
      elsif input = hashing_password?(call)
        confidence = CONFIDENCE[:high]
      else
        confidence = CONFIDENCE[:med]
      end
    else
      confidence = CONFIDENCE[:med]
    end


    alg = case call.target.last
          when :MD5
           " (MD5)"
           when :SHA1
            " (SHA1)"
          else
            ""
          end

    warn :result => result,
      :warning_type => "Weak Hash",
      :warning_code => :weak_hash_digest,
      :message => "Weak hashing algorithm#{alg} used",
      :confidence => confidence,
      :user_input => input
  end

  def process_hmac_result result
    return if duplicate? result
    add_result result

    call = result[:call]

    alg = case call.third_arg.last
           when :MD5
             'MD5'
           when :SHA1
             'SHA1'
           else
             return
           end

    warn :result => result,
      :warning_type => "Weak Hash",
      :warning_code => :weak_hash_hmac,
      :message => "Weak hashing algorithm (#{alg}) used in HMAC",
      :confidence => CONFIDENCE[:med]
  end

  def process_openssl_result result
    return if duplicate? result
    add_result result

    arg = result[:call].first_arg

    if string? arg
      alg = arg.value.upcase

      if alg == 'MD5' or alg == 'SHA1'
        warn :result => result,
          :warning_type => "Weak Hash",
          :warning_code => :weak_hash_digest,
          :message => "Weak hashing algorithm (#{alg}) used",
          :confidence => CONFIDENCE[:med]
      end
    end
  end

  def user_input_as_arg? call
    call.each_arg do |arg|
      if input = include_user_input?(arg)
        return input
      end
    end

    nil
  end

  def hashing_password? call
    call.each_arg do |arg|
      @has_password = false

      process arg

      if @has_password
        return @has_password
      end
    end

    nil
  end

  def process_call exp
    if exp.method == :password
      @has_password = exp
    else
      process_default exp
    end

    exp
  end

  def process_ivar exp
    if exp.value == :@password
      @has_password = exp
    end

    exp
  end

  def process_lvar exp
    if exp.value == :password
      @has_password = exp
    end

    exp
  end
end
