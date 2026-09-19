# frozen_string_literal: true

module TypeSafe
  # Client settings. Explicit values take precedence over environment variables, then SDK defaults.
  #
  # A Configuration starts mutable (used by TypeSafe.configure) and becomes a frozen, validated
  # copy through #resolve, which is what TypeSafe::Client keeps.
  class Configuration
    LOG_LEVELS = {
      debug: Logger::DEBUG, info: Logger::INFO, warn: Logger::WARN, error: Logger::ERROR, fatal: Logger::FATAL
    }.freeze

    # API key; falls back to TYPESAFE_API_KEY.
    attr_accessor :api_key
    # API root; falls back to TYPESAFE_BASE_URL, then https://api.typesafe.ai.
    attr_accessor :base_url
    # Default model; falls back to TYPESAFE_DEFAULT_MODEL, then jev-latest.
    attr_accessor :model
    # Timeout per HTTP attempt in seconds. Default: 10.
    attr_accessor :timeout
    # Additional headers sent with every request.
    attr_accessor :headers
    # Logger; defaults to a Logger on $stderr.
    attr_accessor :logger
    # Log level; falls back to TYPESAFE_LOG_LEVEL, then :warn.
    attr_accessor :log_level
    # Retry policy: a RetryPolicy, or a Hash of overrides on the SDK defaults.
    attr_accessor :retry_policy
    # Custom transport responding to #call(request); defaults to Net::HTTP.
    attr_accessor :transport

    def initialize(api_key: nil, base_url: nil, model: nil, timeout: nil, headers: nil, logger: nil,
                   log_level: nil, retry_policy: nil, transport: nil)
      @api_key = api_key
      @base_url = base_url
      @model = model
      @timeout = timeout
      @headers = headers
      @logger = logger
      @log_level = log_level
      @retry_policy = retry_policy
      @transport = transport
    end

    # The explicitly set options, suitable for splatting into Client.new.
    def to_h
      {
        api_key: api_key, base_url: base_url, model: model, timeout: timeout, headers: headers,
        logger: logger, log_level: log_level, retry_policy: retry_policy, transport: transport
      }.compact
    end

    # Apply environment fallbacks and defaults, validate, and return a frozen copy.
    def resolve(env: ENV)
      resolved = dup
      resolved.api_key = resolve_api_key(env)
      resolved.base_url = resolve_base_url(env)
      resolved.model = resolve_model(env)
      resolved.timeout = resolve_timeout
      resolved.headers = resolve_headers
      resolved.retry_policy = RetryPolicy.from(retry_policy)
      resolve_logging(resolved, env)
      resolved.freeze
    end

    # The Logger severity matching #log_level.
    def logger_severity
      LOG_LEVELS.fetch(log_level.to_s.downcase.to_sym, Logger::WARN)
    end

    private

    def resolve_api_key(env)
      value = api_key.nil? ? Util.env_value(env, Constants::API_KEY_ENV) : api_key.to_s.strip
      return value unless Util.blank?(value)

      raise ConfigurationError,
            "No API key provided. Pass api_key: to TypeSafe::Client.new or set #{Constants::API_KEY_ENV}."
    end

    def resolve_base_url(env)
      value = Util.blank?(base_url) ? Util.env_value(env, Constants::BASE_URL_ENV) : base_url.to_s.strip
      value ||= Constants::DEFAULT_BASE_URL
      uri = URI.parse(value)
      raise ConfigurationError, "base_url must be an http(s) URL, got #{value.inspect}" unless uri.is_a?(URI::HTTP)

      value.sub(%r{/+\z}, "")
    rescue URI::InvalidURIError
      raise ConfigurationError, "base_url must be an http(s) URL, got #{value.inspect}"
    end

    def resolve_model(env)
      value = Util.blank?(model) ? Util.env_value(env, Constants::DEFAULT_MODEL_ENV) : model.to_s.strip
      value || Constants::DEFAULT_MODEL
    end

    def resolve_timeout
      value = timeout.nil? ? Constants::DEFAULT_TIMEOUT : timeout
      unless value.is_a?(Numeric) && value.finite? && value.positive?
        raise ConfigurationError, "timeout must be a positive number of seconds, got #{timeout.inspect}"
      end

      value
    end

    def resolve_headers
      (headers || {}).each_with_object({}) { |(name, value), result| result[name.to_s] = value.to_s }
    end

    def resolve_logging(resolved, env)
      resolved.log_level = resolve_log_level(env)
      resolved.logger = logger || build_logger(resolved.log_level)
    end

    def resolve_log_level(env)
      value = Util.blank?(log_level) ? Util.env_value(env, Constants::LOG_LEVEL_ENV) : log_level
      value = (value || Constants::DEFAULT_LOG_LEVEL).to_s.downcase.to_sym
      return value if LOG_LEVELS.key?(value)

      raise ConfigurationError, "log_level must be one of #{LOG_LEVELS.keys.join(", ")}, got #{value.inspect}"
    end

    def build_logger(level)
      logger = Logger.new($stderr, progname: "typesafe")
      logger.level = LOG_LEVELS.fetch(level)
      logger
    end
  end
end
