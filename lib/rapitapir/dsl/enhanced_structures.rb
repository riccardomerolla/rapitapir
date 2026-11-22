# frozen_string_literal: true

module RapiTapir
  module DSL
    # Enhanced input specification with full type system integration
    class EnhancedInput
      attr_reader :kind, :name, :type, :required, :description, :example, :format, :content_type

      def initialize(kind:, name:, type:, required: true, **options)
        @kind = kind.to_sym
        @name = name.to_sym
        @type = type
        @required = required
        @description = options[:description]
        @example = options[:example]
        @format = options[:format]
        @content_type = options[:content_type]
      end

      def required?
        # Check if the input is required based on:
        # 1. Explicit required parameter
        # 2. Whether the type is optional
        return false if @required == false # Explicitly set to false
        return false if @type.respond_to?(:optional?) && @type.optional?

        @required.nil? || @required # Default to true if not specified
      end

      def optional?
        !@required
      end

      def to_openapi_spec
        spec = {
          name: @name.to_s,
          in: openapi_location,
          required: @required,
          schema: @type.to_json_schema
        }

        spec[:description] = @description if @description
        spec[:example] = @example if @example

        spec
      end

      def validate(value)
        @type.validate(value)
      end

      def coerce(value)
        @type.coerce(value)
      end

      private

      def openapi_location
        case @kind
        when :query
          'query'
        when :path
          'path'
        when :header
          'header'
        when :body
          'requestBody'
        else
          @kind.to_s
        end
      end
    end

    # Enhanced output specification with status codes and content types
    class EnhancedOutput
      attr_reader :status_code, :type, :content_type, :description, :example, :headers

      def initialize(status_code:, type: nil, content_type: 'application/json', **options)
        @status_code = status_code.to_i
        @type = type
        @content_type = content_type
        @description = options[:description]
        @example = options[:example]
        @headers = options[:headers] || {}
      end

      # Legacy compatibility method for validators
      def kind
        return :status if @type.nil?

        case @content_type
        when 'application/xml', 'text/xml'
          :xml
        else # Default to json for application/json and unknown content types
          :json
        end
      end

      def to_openapi_spec
        spec = {
          description: @description || http_status_description
        }

        add_content_to_spec(spec) if @type
        add_headers_to_spec(spec) if @headers.any?

        spec
      end

      def add_content_to_spec(spec)
        spec[:content] = {
          @content_type => {
            schema: @type.to_json_schema
          }
        }

        spec[:content][@content_type][:example] = @example if @example
      end

      def add_headers_to_spec(spec)
        spec[:headers] = @headers.transform_values do |header_spec|
          transform_header_spec(header_spec)
        end
      end

      def transform_header_spec(header_spec)
        case header_spec
        when Hash
          header_spec
        when String
          { description: header_spec }
        else
          { description: header_spec.to_s }
        end
      end

      def validate(value)
        return { valid: true, errors: [] } unless @type

        @type.validate(value)
      end

      def serialize(value)
        return nil unless @type

        case @content_type
        when 'application/json'
          JSON.generate(value)
        when 'text/plain'
          value.to_s
        else
          value
        end
      end

      private

      def http_status_description
        case @status_code
        when 200, 201, 202, 204
          success_status_description
        when 400, 401, 403, 404, 422
          client_error_status_description
        when 500
          'Internal Server Error'
        else
          "HTTP #{@status_code}"
        end
      end

      def success_status_description
        case @status_code
        when 200 then 'OK'
        when 201 then 'Created'
        when 202 then 'Accepted'
        when 204 then 'No Content'
        end
      end

      def client_error_status_description
        case @status_code
        when 400 then 'Bad Request'
        when 401 then 'Unauthorized'
        when 403 then 'Forbidden'
        when 404 then 'Not Found'
        when 422 then 'Unprocessable Entity'
        end
      end
    end

    # Enhanced error specification for detailed error responses
    class EnhancedError
      attr_reader :status_code, :type, :description, :example

      def initialize(status_code:, type: nil, description: nil, example: nil)
        @status_code = status_code.to_i
        @type = type
        @description = description
        @example = example
      end

      def to_openapi_spec
        spec = {
          description: @description || http_error_description
        }

        if @type
          spec[:content] = {
            'application/json' => {
              schema: @type.to_json_schema
            }
          }

          spec[:content]['application/json'][:example] = @example if @example
        end

        spec
      end

      def matches?(error)
        error.respond_to?(:status_code) && error.status_code == @status_code
      end

      private

      def http_error_description
        case @status_code
        when 400
          'Bad Request - Invalid input parameters'
        when 401
          'Unauthorized - Authentication required'
        when 403
          'Forbidden - Insufficient permissions'
        when 404
          'Not Found - Resource not found'
        when 422
          'Unprocessable Entity - Validation failed'
        when 500
          'Internal Server Error - Server encountered an error'
        else
          "HTTP Error #{@status_code}"
        end
      end
    end

    # Enhanced security specification for authentication schemes
    class EnhancedSecurity
      attr_reader :type, :description, :name, :location, :scopes, :flows

      def initialize(type:, description:, **config)
        @type = type.to_sym
        @description = description
        @name = config[:name]
        @location = config[:location]&.to_sym
        @scopes = Array(config[:scopes] || [])
        @flows = config[:flows]
        @options = config.except(:name, :location, :scopes, :flows)
      end

      def to_openapi_spec
        spec = {
          type: openapi_type,
          description: @description
        }

        add_auth_specific_fields(spec)
        spec
      end

      def add_auth_specific_fields(spec)
        case @type
        when :bearer
          add_bearer_fields(spec)
        when :api_key
          add_api_key_fields(spec)
        when :basic
          add_basic_fields(spec)
        when :oauth2
          add_oauth2_fields(spec)
        end
      end

      def add_bearer_fields(spec)
        spec[:scheme] = 'bearer'
        spec[:bearerFormat] = @options[:bearer_format] if @options[:bearer_format]
      end

      def add_api_key_fields(spec)
        spec[:name] = @name || 'X-API-Key'
        spec[:in] = (@location || :header).to_s
      end

      def add_basic_fields(spec)
        spec[:scheme] = 'basic'
      end

      def add_oauth2_fields(spec)
        spec[:flows] = @flows || default_oauth2_flows
      end

      def validate_request(request)
        case @type
        when :bearer
          validate_bearer_token(request)
        when :api_key
          validate_api_key(request)
        when :basic
          validate_basic_auth(request)
        when :oauth2
          validate_oauth2_token(request)
        else
          { valid: false, error: "Unsupported auth type: #{@type}" }
        end
      end

      private

      def openapi_type
        case @type
        when :bearer, :basic
          'http'
        when :api_key
          'apiKey'
        when :oauth2
          'oauth2'
        else
          @type.to_s
        end
      end

      def default_oauth2_flows
        {
          implicit: {
            authorizationUrl: @options[:authorization_url] || 'https://example.com/oauth/authorize',
            scopes: @scopes.to_h { |scope| [scope, scope.to_s.humanize] }
          }
        }
      end

      def validate_bearer_token(request)
        auth_header = request.env['HTTP_AUTHORIZATION']
        return { valid: false, error: 'Missing Authorization header' } unless auth_header

        return { valid: false, error: 'Invalid Authorization header format' } unless auth_header.start_with?('Bearer ')

        token = auth_header[7..] # Remove 'Bearer ' prefix
        return { valid: false, error: 'Empty token' } if token.empty?

        { valid: true, token: token }
      end

      def validate_api_key(request)
        key_name = @name || 'X-API-Key'

        key_value = case @location
                    when :query
                      request.params[key_name]
                    else # Default to header for :header and unknown locations
                      request.env["HTTP_#{key_name.upcase.gsub('-', '_')}"]
                    end

        return { valid: false, error: "Missing API key: #{key_name}" } unless key_value
        return { valid: false, error: 'Empty API key' } if key_value.empty?

        { valid: true, api_key: key_value }
      end

      def validate_basic_auth(request)
        auth_header = request.env['HTTP_AUTHORIZATION']
        return { valid: false, error: 'Missing Authorization header' } unless auth_header

        return { valid: false, error: 'Invalid Authorization header format' } unless auth_header.start_with?('Basic ')

        encoded_credentials = auth_header[6..] # Remove 'Basic ' prefix
        return { valid: false, error: 'Empty credentials' } if encoded_credentials.empty?

        begin
          decoded_credentials = Base64.decode64(encoded_credentials)
          username, password = decoded_credentials.split(':', 2)
          { valid: true, username: username, password: password }
        rescue StandardError => e
          { valid: false, error: "Invalid credentials encoding: #{e.message}" }
        end
      end

      def validate_oauth2_token(request)
        # OAuth2 validation would typically involve token introspection
        # For now, we'll do basic Bearer token validation
        validate_bearer_token(request)
      end
    end
  end
end
