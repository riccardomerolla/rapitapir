# frozen_string_literal: true

source 'https://rubygems.org'

gem 'dotenv', '~> 3.2' # For environment variable management
gem 'json', '~> 3.1'
gem 'jwt', '~> 3.3' # For OAuth2 JWT validation
gem 'rack', '~> 3.2'
gem 'webrick', '~> 1.9' # For CLI server functionality

group :development, :test do
  gem 'puma', '~> 8.1'
  gem 'rack-test', '~> 2.3'
  gem 'rspec', '~> 3.13'
  gem 'simplecov', '~> 1.3'
  gem 'sinatra', '~> 4.2'
  gem 'webmock', '~> 3.38'
  # public_suffix 7 requires Ruby >= 3.2; keep 6.x for the gem's >= 3.1 support
  gem 'public_suffix', '~> 6.0'
  # Linting and style
  gem 'rubocop', '~> 1.92'
end

gem 'rackup', '~> 2.3'

# OpenTelemetry for observability (Honeycomb.io integration)
gem 'opentelemetry-exporter-otlp', '~> 0.37'
gem 'opentelemetry-instrumentation-all', '~> 0.102'
gem 'opentelemetry-sdk', '~> 1.13'
# opentelemetry-api 1.9+ requires Ruby >= 3.3; keep 1.8 for the gem's >= 3.1 support
gem 'opentelemetry-api', '~> 1.8.0'
