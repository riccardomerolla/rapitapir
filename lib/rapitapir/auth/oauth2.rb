# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module RapiTapir
  module Auth
    module OAuth2
      # Enhanced OAuth2 authentication scheme with Auth0 support
      # Based on the Auth0 Sinatra integration patterns
      class Auth0Scheme < Schemes::Base
        attr_reader :domain, :audience, :algorithm, :jwks_cache_ttl

        def jwks_url
          "https://#{@domain}/.well-known/jwks.json"
        end

        def initialize(name = :oauth2_auth0, config = {})
          super

          @domain = config[:domain] || raise(ArgumentError, 'Auth0 domain is required')
          @audience = config[:audience] || raise(ArgumentError, 'Auth0 audience is required')
          @algorithm = config[:algorithm] || 'RS256'
          @jwks_cache_ttl = config[:jwks_cache_ttl] || 300 # 5 minutes
          @realm = config[:realm] || 'API'

          # Cache for JWKS to avoid frequent requests
          @jwks_cache = nil
          @jwks_cache_time = nil
        end

        def authenticate(request)
          auth_header = request.env['HTTP_AUTHORIZATION']
          return nil unless auth_header

          token = extract_bearer_token(auth_header)
          raise AuthenticationError, 'Invalid authorization header format' if token.nil?

          raise AuthenticationError, 'Token cannot be empty' if token.strip.empty?

          begin
            decoded_token = validate_auth0_token(token)
            return nil unless decoded_token

            # Extract user info and scopes from the token
            payload = decoded_token.first

            create_context(
              user: extract_user_from_token(payload),
              scopes: extract_scopes_from_token(payload),
              token: token,
              metadata: {
                token_type: 'oauth2_auth0',
                issuer: payload['iss'],
                subject: payload['sub'],
                audience: payload['aud'],
                expires_at: payload['exp'] ? Time.at(payload['exp']) : nil,
                issued_at: payload['iat'] ? Time.at(payload['iat']) : nil
              }
            )
          rescue JWT::VerificationError, JWT::DecodeError => e
            raise InvalidTokenError, "Invalid Auth0 token: #{e.message}"
          rescue StandardError => e
            raise AuthenticationError, "Auth0 authentication failed: #{e.message}"
          end
        end

        def challenge
          "Bearer realm=\"#{@realm}\", error=\"invalid_token\", error_description=\"The access token provided is expired, revoked, malformed, or invalid\""
        end

        # Public method to verify token (useful for testing)
        def verify_token(token)
          validate_auth0_token(token)
        end

        private

        def extract_bearer_token(auth_header)
          match = auth_header.match(/\ABearer\s+(.+)\z/i)
          match ? match[1] : nil
        end

        def validate_auth0_token(token)
          require 'jwt' # Ensure JWT gem is available

          jwks = fetch_jwks

          JWT.decode(
            token,
            nil,
            {
              verify_signature: true,
              algorithm: @algorithm,
              iss: domain_url,
              verify_iss: true,
              aud: @audience,
              verify_aud: true,
              jwks: jwks
            }
          )
        end

        def fetch_jwks
          # Return cached JWKS if still valid
          return @jwks_cache if @jwks_cache && @jwks_cache_time && (Time.now - @jwks_cache_time) < @jwks_cache_ttl

          # Fetch fresh JWKS from Auth0
          jwks_response = get_jwks_from_auth0

          raise AuthenticationError, 'Unable to fetch JWKS from Auth0' unless jwks_response.is_a?(Net::HTTPSuccess)

          jwks_data = JSON.parse(jwks_response.body)

          # Cache the JWKS
          @jwks_cache = { keys: jwks_data['keys'] }
          @jwks_cache_time = Time.now

          @jwks_cache
        end

        def get_jwks_from_auth0
          jwks_uri = URI("#{base_domain_url}/.well-known/jwks.json")

          http = Net::HTTP.new(jwks_uri.host, jwks_uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.read_timeout = 10

          request = Net::HTTP::Get.new(jwks_uri.request_uri)
          request['User-Agent'] = 'RapiTapir OAuth2 Client'

          http.request(request)
        end

        def domain_url
          url = @domain.start_with?('https://') ? @domain : "https://#{@domain}"
          # Auth0 issuer always includes trailing slash for JWT validation
          @domain_url ||= url.end_with?('/') ? url : "#{url}/"
        end

        def base_domain_url
          @base_domain_url ||= @domain.start_with?('https://') ? @domain : "https://#{@domain}"
        end

        def extract_user_from_token(payload)
          {
            id: payload['sub'],
            email: payload['email'],
            name: payload['name'] || payload['nickname'],
            picture: payload['picture'],
            email_verified: payload['email_verified']
          }.compact
        end

        def extract_scopes_from_token(payload)
          scope_string = payload['scope']
          return [] unless scope_string

          scope_string.split
        end
      end

      # Generic OAuth2 scheme with token introspection support
      class GenericScheme < Schemes::Base
        attr_reader :introspection_endpoint, :client_id, :client_secret, :token_cache_ttl

        def initialize(name = :oauth2, config = {})
          super

          @introspection_endpoint = config[:introspection_endpoint]
          @client_id = config[:client_id]
          @client_secret = config[:client_secret]
          @token_validator = config[:token_validator]
          @realm = config[:realm] || 'API'
          @cache_tokens = config.fetch(:cache_tokens, true)
          @token_cache_ttl = config[:token_cache_ttl] || 300 # 5 minutes

          # Token cache to avoid repeated introspection calls
          @token_cache = {} if @cache_tokens
        end

        def authenticate(request)
          auth_header = request.env['HTTP_AUTHORIZATION']
          return nil unless auth_header

          token = extract_bearer_token(auth_header)
          return nil unless token

          begin
            token_info = validate_oauth2_token(token)

            # Check if token is active
            raise AuthenticationError, 'Token is not active' unless token_info && token_info[:active]

            create_context(
              user: token_info[:user],
              scopes: token_info[:scopes] || [],
              token: token,
              metadata: {
                token_type: 'oauth2',
                client_id: token_info[:client_id],
                expires_at: token_info[:expires_at],
                token_type_hint: token_info[:token_type]
              }
            )
          rescue AuthenticationError
            raise # Re-raise authentication errors
          rescue StandardError => e
            raise AuthenticationError, "OAuth2 authentication failed: #{e.message}"
          end
        end

        def challenge
          "Bearer realm=\"#{@realm}\""
        end

        # Public method for token validation (useful for testing)
        def validate_token(token)
          validate_oauth2_token(token)
        end

        private

        def extract_bearer_token(auth_header)
          match = auth_header.match(/\ABearer\s+(.+)\z/i)
          match ? match[1] : nil
        end

        def validate_oauth2_token(token)
          # Check cache first
          if @cache_tokens && @token_cache
            cached = @token_cache[token]
            return cached[:data] if cached && (Time.now - cached[:cached_at]) < @token_cache_ttl
          end

          # Validate token
          token_info = if @introspection_endpoint
                         introspect_token_via_endpoint(token)
                       elsif @token_validator
                         @token_validator.call(token)
                       else
                         default_token_validation(token)
                       end

          # Cache the result
          if @cache_tokens && @token_cache && token_info
            @token_cache[token] = {
              data: token_info,
              cached_at: Time.now
            }
          end

          token_info
        end

        def introspect_token_via_endpoint(token)
          uri = URI(@introspection_endpoint)

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')

          request = Net::HTTP::Post.new(uri.request_uri)
          request['Content-Type'] = 'application/x-www-form-urlencoded'
          request['Accept'] = 'application/json'

          # Add client authentication
          if @client_id && @client_secret
            credentials = Base64.strict_encode64("#{@client_id}:#{@client_secret}")
            request['Authorization'] = "Basic #{credentials}"
          end

          # Set form data
          request.set_form_data(
            'token' => token,
            'token_type_hint' => 'access_token'
          )

          response = http.request(request)

          raise AuthenticationError, "Token introspection failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

          begin
            introspection_data = JSON.parse(response.body)
          rescue JSON::ParserError => e
            raise AuthenticationError, "Invalid introspection response: #{e.message}"
          end

          return { active: false } unless introspection_data['active']

          {
            active: true,
            user: extract_user_from_introspection(introspection_data),
            scopes: extract_scopes_from_introspection(introspection_data),
            client_id: introspection_data['client_id'],
            expires_at: introspection_data['exp'] ? Time.at(introspection_data['exp']) : nil,
            token_type: introspection_data['token_type'] || 'Bearer'
          }
        end

        def extract_user_from_introspection(data)
          {
            id: data['sub'] || data['user_id'],
            username: data['username'],
            email: data['email'],
            name: data['name']
          }.compact
        end

        def extract_scopes_from_introspection(data)
          if data['scope'].is_a?(String)
            data['scope'].split
          elsif data['scope'].is_a?(Array)
            data['scope']
          else
            []
          end
        end

        def default_token_validation(token)
          # Simple default validation - should be overridden in production
          return { active: false } if token.nil? || token.empty?

          {
            active: true,
            user: { id: 'default_user', name: 'Default User' },
            scopes: %w[read],
            client_id: 'default_client',
            expires_at: Time.now + 3600
          }
        end
      end
    end
  end
end
