# RapiTapir

[![Tests](https://img.shields.io/badge/tests-695%20passing-brightgreen)](spec/)
[![Coverage](https://img.shields.io/badge/coverage-72.7%25-green)](coverage/)
[![Branches](https://img.shields.io/badge/branches-44.89%25-yellow)](coverage/)
[![Ruby](https://img.shields.io/badge/ruby-3.3%2B-red)](Gemfile)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![RuboCop](https://img.shields.io/badge/code%20style-rubocop-brightgreen)](https://github.com/rubocop/rubocop)
[![AI Ready](https://img.shields.io/badge/AI-LLM%20%7C%20RAG%20%7C%20MCP-purple)](lib/rapitapir/ai/)

**RapiTapir 🦙** combines the expressiveness of Ruby with the safety of strong typing to create APIs that are both powerful and reliable. Define your endpoints once with our fluent DSL, and get automatic validation, documentation, client generation, and AI-powered features.

## 🚀 Latest Features (v2.0)

- **🤖 AI Integration**: Built-in LLM instruction generation, RAG pipelines, and MCP export
- **✨ SinatraRapiTapir Base Class**: `class MyAPI < SinatraRapiTapir` - zero-boilerplate API creation
- **🎯 Enhanced HTTP DSL**: Native GET, POST, PUT, DELETE methods with fluent chaining  
- **🔧 Zero Configuration**: Automatic extension registration and intelligent defaults
- **⚡ T Shortcut**: Use `T.string` instead of `RapiTapir::Types.string` everywhere
- **📚 GitHub Pages Ready**: Modern documentation deployment with GitHub Actions
- **🔍 CLI Toolkit**: Complete command-line interface for generation, validation, and serving
- **🧪 Comprehensive Tests**: 695 examples, 0 failures; 72.7% coverage

## ✨ Why RapiTapir?

- **🔒 Type Safety**: Strong typing with runtime validation and compile-time confidence
- **📖 Auto Documentation**: OpenAPI 3.0 specs generated automatically from your code
- **🚀 Framework Agnostic**: Works with Sinatra, Rails, and any Rack-based framework  
- **🛡️ Production Ready**: Built-in security, observability, and authentication features
- **💎 Ruby Native**: Designed specifically for Ruby developers who love clean, readable code
- **🔧 Zero Config**: Get started in minutes with sensible defaults
- **🤖 AI Powered**: Built-in LLM instruction generation, RAG pipelines, and MCP export
- **⚡ Enhanced DSL**: Clean syntax with `T.string`, HTTP verbs, and resource builders
- **🔄 CLI Toolkit**: Complete command-line interface for all development tasks

## 🚀 Quick Start

### Minimal Example (30 seconds)

```ruby
require 'rapitapir'

class HelloAPI < SinatraRapiTapir
  # That's it! Zero configuration needed.
  endpoint(
    GET('/hello')
      .query(:name, T.string, description: 'Your name')
      .ok(T.hash({ "message" => T.string }))
      .build
  ) { |inputs| { message: "Hello, #{inputs[:name]}!" } }
  
  run! if __FILE__ == $0
end
```

**Start server**: `ruby hello_api.rb`  
**Try it**: `curl "http://localhost:4567/hello?name=World"`  
**Docs**: `http://localhost:4567/docs`

### Complete Example (5 minutes)

```ruby
require 'rapitapir'

class BookAPI < SinatraRapiTapir
  # Configure API information
  rapitapir do
    info(
      title: 'Book Management API',
      description: 'A comprehensive book management system with AI features',
      version: '2.0.0'
    )
    development_defaults! # Auto CORS, docs, health checks, metrics
  end

  # Define schemas using T shortcut (available everywhere!)
  BOOK_SCHEMA = T.hash({
    "id" => T.integer,
    "title" => T.string(min_length: 1, max_length: 255),
    "author" => T.string(min_length: 1),
    "published" => T.boolean,
    "isbn" => T.optional(T.string(pattern: /^\d{13}$/)),
    "pages" => T.optional(T.integer(minimum: 1)),
    "tags" => T.optional(T.array(T.string)),
    "metadata" => T.optional(T.hash({
      "genre" => T.string,
      "rating" => T.float(minimum: 0, maximum: 5)
    }))
  })

  # RESTful resource with full CRUD
  api_resource '/books', schema: BOOK_SCHEMA do
    crud do
      index do
        # Automatic pagination and filtering
        books = Book.all
        books = books.where(published: true) if params[:published] == 'true'
        books.limit(params[:limit] || 50).map(&:to_h)
      end
      
      show { |inputs| Book.find(inputs[:id])&.to_h || halt(404) }
      
      create do |inputs|
        book = Book.create(inputs[:body])
        status 201
        book.to_h
      end
      
      update { |inputs| Book.update(inputs[:id], inputs[:body]).to_h }
      destroy { |inputs| Book.delete(inputs[:id]); status 204 }
    end
    
    # Custom endpoints with full type safety
    custom :get, 'featured' do
      Book.where(featured: true).map(&:to_h)
    end
    
    custom :post, ':id/reviews' do |inputs|
      book = Book.find(inputs[:id])
      review = book.add_review(inputs[:body])
      status 201
      review.to_h
    end
  end

  # Advanced search with AI-powered features
  endpoint(
    GET('/books/search')
      .query(:q, T.string(min_length: 1), description: 'Search query')
      .query(:limit, T.optional(T.integer(minimum: 1, maximum: 100)), description: 'Results limit')
      .query(:ai_powered, T.optional(T.boolean), description: 'Use AI-enhanced search')
      .summary('Search books with optional AI enhancement')
      .description('Search books by title, author, or content with optional AI semantic search')
      .tags('Search', 'AI')
      .ok(T.hash({
        "books" => T.array(BOOK_SCHEMA),
        "total" => T.integer,
        "ai_enhanced" => T.boolean,
        "suggestions" => T.optional(T.array(T.string))
      }))
      .bad_request(T.hash({ "error" => T.string }))
      .enable_rag # AI-powered retrieval augmented generation
      .enable_mcp # Export to Model Context Protocol
      .build
  ) do |inputs|
    query = inputs[:q]
    limit = inputs[:limit] || 20
    ai_powered = inputs[:ai_powered] || false
    
    if ai_powered
      # Use AI-enhanced search
      results = BookSearchService.ai_search(query, limit: limit)
      suggestions = BookSearchService.get_suggestions(query)
    else
      results = Book.search(query).limit(limit)
      suggestions = nil
    end
    
    {
      books: results.map(&:to_h),
      total: results.count,
      ai_enhanced: ai_powered,
      suggestions: suggestions
    }
  end

  run! if __FILE__ == $0
end
```

**Start and explore**:
- **Server**: `ruby book_api.rb`
- **Interactive Docs**: `http://localhost:4567/docs`
- **OpenAPI Spec**: `http://localhost:4567/openapi.json`
- **Health Check**: `http://localhost:4567/health`
## 🏗️ Advanced Features

### 🤖 AI-Powered APIs

```ruby
class AIBookAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'AI-Powered Book API', version: '2.0.0')
    development_defaults!
  end

  # Configure AI providers
  configure do
    set :openai_api_key, ENV['OPENAI_API_KEY']
    set :rag_backend, :memory # or :elasticsearch, :postgresql
  end

  # AI-enhanced book recommendations
  endpoint(
    GET('/books/recommendations')
      .query(:user_id, T.integer, description: 'User ID for personalization')
      .query(:preferences, T.optional(T.string), description: 'User preferences text')
      .summary('Get AI-powered book recommendations')
      .description('Uses LLM to generate personalized book recommendations')
      .tags('AI', 'Recommendations')
      .ok(T.hash({
        "recommendations" => T.array(BOOK_SCHEMA),
        "reasoning" => T.string,
        "confidence" => T.float(minimum: 0, maximum: 1)
      }))
      .enable_llm_instructions(purpose: :completion) # Generate LLM instructions
      .enable_rag(
        retrieval_backend: :memory,
        llm_provider: :openai,
        context_window: 4000
      )
      .enable_mcp # Export for AI agent consumption
      .build
  ) do |inputs|
    user = User.find(inputs[:user_id])
    preferences = inputs[:preferences] || user.inferred_preferences
    
    # RAG pipeline automatically injects relevant context
    recommendations = AIRecommendationService.generate(
      user: user,
      preferences: preferences,
      context: rag_context # Automatically provided by RAG middleware
    )
    
    {
      recommendations: recommendations[:books],
      reasoning: recommendations[:explanation],
      confidence: recommendations[:confidence_score]
    }
  end

  # LLM instruction generation endpoint
  endpoint(
    GET('/ai/instructions')
      .query(:endpoint_id, T.string, description: 'Endpoint ID to generate instructions for')
      .query(:purpose, T.string(enum: %w[validation transformation analysis documentation testing completion]), 
             description: 'Instruction purpose')
      .summary('Generate LLM instructions for endpoints')
      .ok(T.hash({
        "instructions" => T.string,
        "metadata" => T.hash({
          "endpoint" => T.string,
          "purpose" => T.string,
          "generated_at" => T.datetime
        })
      }))
      .build
  ) do |inputs|
    generator = RapiTapir::AI::LLMInstruction::Generator.new
    endpoint = find_endpoint(inputs[:endpoint_id])
    
    instructions = generator.generate_instructions(
      endpoint: endpoint,
      purpose: inputs[:purpose].to_sym
    )
    
    {
      instructions: instructions,
      metadata: {
        endpoint: endpoint.summary || endpoint.path,
        purpose: inputs[:purpose],
        generated_at: Time.now
      }
    }
  end

  # Export Model Context Protocol (MCP) for AI agents
  endpoint(
    GET('/mcp/export')
      .summary('Export API for AI agent consumption')
      .description('Generates MCP-compatible JSON for AI agents and development tools')
      .tags('AI', 'MCP', 'Developer Tools')
      .ok(T.hash({
        "service" => T.hash({
          "name" => T.string,
          "version" => T.string,
          "description" => T.string
        }),
        "endpoints" => T.array(T.hash({
          "id" => T.string,
          "method" => T.string,
          "path" => T.string,
          "summary" => T.string,
          "input_schema" => T.hash({}),
          "output_schema" => T.hash({})
        })),
        "generated_at" => T.datetime
      }))
      .build
  ) do
    exporter = RapiTapir::AI::MCP::Exporter.new(rapitapir_endpoints)
    JSON.parse(exporter.export_json(pretty: true))
  end

  run! if __FILE__ == $0
end
```

### 🔐 OAuth2 + Auth0 Integration

```ruby
class SecureAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'Secure API with Auth0', version: '2.0.0')
    
    # Configure Auth0 OAuth2
    oauth2_auth0 :auth0,
      domain: ENV['AUTH0_DOMAIN'],
      audience: ENV['AUTH0_AUDIENCE'],
      realm: 'API Access'
    
    production_defaults! # Security headers, rate limiting, etc.
  end

  # Public endpoints
  endpoint(
    GET('/public/status')
      .summary('Public API status')
      .ok(T.hash({
        "status" => T.string,
        "version" => T.string,
        "authenticated" => T.boolean
      }))
      .build
  ) do
    {
      status: 'operational',
      version: '2.0.0',
      authenticated: authenticated?
    }
  end

  # Protected endpoints with scope requirements
  endpoint(
    GET('/users/profile')
      .summary('Get current user profile')
      .description('Requires valid Auth0 token with read:profile scope')
      .bearer_auth(scopes: ['read:profile'])
      .tags('Users', 'Profile')
      .ok(T.hash({
        "user" => T.hash({
          "id" => T.string,
          "email" => T.string,
          "name" => T.string,
          "roles" => T.array(T.string),
          "permissions" => T.array(T.string)
        }),
        "metadata" => T.hash({
          "last_login" => T.datetime,
          "login_count" => T.integer
        })
      }))
      .error_response(401, T.hash({ "error" => T.string }), description: 'Unauthorized')
      .error_response(403, T.hash({ "error" => T.string }), description: 'Insufficient permissions')
      .build
  ) do |inputs|
    # Current user automatically available from Auth0 context
    user_info = current_auth_context[:user_info]
    
    {
      user: {
        id: user_info['sub'],
        email: user_info['email'],
        name: user_info['name'],
        roles: user_info['roles'] || [],
        permissions: current_auth_context[:permissions] || []
      },
      metadata: {
        last_login: Time.parse(user_info['updated_at']),
        login_count: user_info['logins_count'] || 0
      }
    }
  end

  # Admin-only endpoints
  endpoint(
    DELETE('/admin/users/:user_id')
      .summary('Delete user (admin only)')
      .path_param(:user_id, T.string, description: 'User ID to delete')
      .bearer_auth(scopes: ['delete:users', 'admin'])
      .tags('Admin', 'Users')
      .ok(T.hash({ "message" => T.string, "deleted_user_id" => T.string }))
      .error_response(401, T.hash({ "error" => T.string }))
      .error_response(403, T.hash({ "error" => T.string }))
      .error_response(404, T.hash({ "error" => T.string }))
      .build
  ) do |inputs|
    # Verify admin scope
    require_scope!('admin')
    
    user_id = inputs[:user_id]
    deleted_user = UserService.delete(user_id)
    
    halt 404, { error: 'User not found' }.to_json unless deleted_user
    
    {
      message: 'User successfully deleted',
      deleted_user_id: user_id
    }
  end

  # Scope-based middleware protection
  protect_with_oauth2 scopes: ['api:access'] do
    # All endpoints in this block require the api:access scope
    
    endpoint(
      GET('/protected/data')
        .summary('Get protected data')
        .ok(T.array(T.hash({ "id" => T.integer, "data" => T.string })))
        .build
    ) { ProtectedData.all.map(&:to_h) }
  end

  run! if __FILE__ == $0
end
```

### 📊 Production Observability (OpenTelemetry + Honeycomb)

```ruby
class MonitoredAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'Production API with Full Observability', version: '2.0.0')
    
    # Configure comprehensive observability
    enable_observability do |config|
      # Health checks with custom checks
      config.health_checks.enable(path: '/health')
      config.health_checks.add_check('database') { DatabaseHealthCheck.new }
      config.health_checks.add_check('redis') { RedisHealthCheck.new }
      config.health_checks.add_check('external_api') { ExternalAPIHealthCheck.new }
      
      # OpenTelemetry tracing
      config.tracing.enable_opentelemetry(
        service_name: 'book-api',
        service_version: '2.0.0',
        environment: ENV['RAILS_ENV'] || 'development',
        exporters: [:otlp, :honeycomb]
      )
      
      # Prometheus metrics
      config.metrics.enable_prometheus(
        namespace: 'book_api',
        default_labels: {
          service: 'book-api',
          version: '2.0.0',
          environment: ENV['RAILS_ENV'] || 'development'
        }
      )
      
      # Structured logging
      config.logging.enable_structured(
        level: ENV['LOG_LEVEL'] || 'info',
        format: :json,
        additional_fields: {
          service: 'book-api',
          version: '2.0.0'
        }
      )
    end
    
    production_defaults!
  end

  # Monitored endpoint with custom metrics and tracing
  endpoint(
    GET('/books/:id')
      .path_param(:id, T.integer, description: 'Book ID')
      .query(:include, T.optional(T.array(T.string)), description: 'Related data to include')
      .summary('Get book with full observability')
      .description('Demonstrates comprehensive monitoring, tracing, and metrics')
      .tags('Books', 'Monitoring')
      .ok(BOOK_SCHEMA)
      .error_response(404, T.hash({ "error" => T.string, "book_id" => T.integer }))
      .error_response(500, T.hash({ "error" => T.string, "trace_id" => T.string }))
      .with_metrics('book_requests', labels: { operation: 'get_by_id' })
      .with_tracing('fetch_book', tags: { book_operation: 'get' })
      .build
  ) do |inputs|
    book_id = inputs[:id]
    includes = inputs[:include] || []
    
    # Custom span for database operation
    OpenTelemetry.tracer.in_span('database.book.find', attributes: { 'book.id' => book_id }) do |span|
      start_time = Time.now
      
      begin
        book = Book.find(book_id)
        
        # Record custom metrics
        Prometheus.increment('book_lookups_total', labels: { found: 'true' })
        Prometheus.observe('book_lookup_duration_seconds', Time.now - start_time)
        
        # Add trace attributes
        span.set_attribute('book.title', book.title)
        span.set_attribute('book.author', book.author)
        span.set_attribute('includes.count', includes.length)
        
        halt 404, { error: 'Book not found', book_id: book_id }.to_json unless book
        
        # Handle includes with additional tracing
        if includes.any?
          OpenTelemetry.tracer.in_span('book.load_includes') do |include_span|
            include_span.set_attribute('includes', includes.join(','))
            book = book.with_includes(includes)
          end
        end
        
        # Log structured data
        logger.info('Book retrieved successfully', {
          book_id: book_id,
          includes: includes,
          duration_ms: ((Time.now - start_time) * 1000).round(2),
          trace_id: span.context.trace_id.unpack1('H*')
        })
        
        book.to_h
        
      rescue StandardError => e
        # Record error metrics
        Prometheus.increment('book_lookup_errors_total', labels: { error_type: e.class.name })
        
        # Add error to span
        span.record_exception(e)
        span.status = OpenTelemetry::Trace::Status.error('Book lookup failed')
        
        # Log error with context
        logger.error('Book lookup failed', {
          book_id: book_id,
          error: e.message,
          error_class: e.class.name,
          trace_id: span.context.trace_id.unpack1('H*')
        })
        
        halt 500, { 
          error: 'Internal server error', 
          trace_id: span.context.trace_id.unpack1('H*') 
        }.to_json
      end
    end
  end

  # Performance monitoring endpoint
  endpoint(
    GET('/monitoring/performance')
      .summary('Get API performance metrics')
      .description('Returns real-time performance and health metrics')
      .tags('Monitoring', 'Performance')
      .bearer_auth(scopes: ['monitoring:read'])
      .ok(T.hash({
        "metrics" => T.hash({
          "request_rate" => T.float,
          "error_rate" => T.float,
          "average_response_time" => T.float,
          "p95_response_time" => T.float
        }),
        "health" => T.hash({
          "overall_status" => T.string,
          "checks" => T.hash({})
        }),
        "trace_sample" => T.optional(T.hash({
          "trace_id" => T.string,
          "span_count" => T.integer,
          "duration_ms" => T.float
        }))
      }))
      .build
  ) do
    {
      metrics: {
        request_rate: MetricsCollector.request_rate_per_second,
        error_rate: MetricsCollector.error_rate_percentage,
        average_response_time: MetricsCollector.average_response_time_ms,
        p95_response_time: MetricsCollector.p95_response_time_ms
      },
      health: {
        overall_status: HealthChecker.overall_status,
        checks: HealthChecker.detailed_status
      },
      trace_sample: TracingCollector.recent_trace_sample
    }
  end

  run! if __FILE__ == $0
end
```

### 🛠️ CLI Development Toolkit

RapiTapir includes a comprehensive CLI for all development tasks:

```bash
# Generate and validate
rapitapir generate openapi --output api-spec.json
rapitapir generate client typescript --output client/api.ts
rapitapir generate docs markdown --output API.md
rapitapir validate endpoints --file my_api.rb

# AI-powered features
rapitapir llm generate --endpoint-id "get_books" --purpose validation
rapitapir llm export --format instructions --output ai-prompts/
rapitapir mcp export --output mcp-context.json

# Development server
rapitapir serve --port 3000 --docs-path /documentation
rapitapir docs --serve --port 8080

# Project scaffolding
rapitapir new my-api --template sinatra-ai
rapitapir generate scaffold books --with-auth --with-ai
```

## 🏗️ Core Features

### ✨ SinatraRapiTapir Base Class

The cleanest way to create APIs with zero boilerplate:

```ruby
require 'rapitapir'

class MyAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'My API', version: '2.0.0')
    development_defaults! # Auto CORS, docs, health checks, metrics
  end

  # Enhanced HTTP verb DSL + T shortcut automatically available
  endpoint(
    GET('/items')
      .summary('List all items')
      .query(:filter, T.optional(T.string), description: 'Filter criteria')
      .ok(T.array(T.hash({ "id" => T.integer, "name" => T.string })))
      .build
  ) { |inputs| Item.filtered(inputs[:filter]).map(&:to_h) }
end
```

### 🔒 Type-Safe API Design

Define schemas once, use everywhere with runtime validation:

```ruby
# T shortcut available globally - no imports needed!
USER_SCHEMA = T.hash({
  "id" => T.integer,
  "name" => T.string(min_length: 1, max_length: 100),
  "email" => T.email,
  "age" => T.optional(T.integer(minimum: 0, maximum: 150)),
  "preferences" => T.optional(T.hash({
    "theme" => T.string(enum: %w[light dark auto]),
    "notifications" => T.boolean,
    "languages" => T.array(T.string)
  })),
  "metadata" => T.optional(T.hash({})) # Free-form metadata
})

# Auto-derive schemas from existing data
INFERRED_SCHEMA = T.from_hash({
  id: 1,
  name: "John Doe",
  active: true,
  tags: ["admin", "power-user"]
})
```

### 🚀 Enhanced HTTP Verb DSL

Fluent, chainable endpoint definitions:

```ruby
# All HTTP verbs available with full type safety
endpoint(
  POST('/users')
    .summary('Create a new user')
    .description('Creates a user with validation and returns the created resource')
    .tags('Users', 'CRUD')
    .body(USER_SCHEMA, description: 'User data to create')
    .header('X-Request-ID', T.optional(T.string), description: 'Request tracking ID')
    .ok(USER_SCHEMA, description: 'Successfully created user')
    .error_response(400, T.hash({
      "error" => T.string,
      "validation_errors" => T.array(T.hash({
        "field" => T.string,
        "message" => T.string,
        "code" => T.string
      }))
    }), description: 'Validation failed')
    .error_response(409, T.hash({ "error" => T.string }), description: 'User already exists')
    .build
) do |inputs|
  begin
    user = UserService.create(inputs[:body])
    status 201
    user.to_h
  rescue ValidationError => e
    halt 400, { 
      error: 'Validation failed', 
      validation_errors: e.details 
    }.to_json
  rescue ConflictError => e
    halt 409, { error: e.message }.to_json
  end
end
```

### 🏭 RESTful Resource Builder

Complete CRUD APIs with minimal code:

```ruby
api_resource '/users', schema: USER_SCHEMA do
  # Configure resource-level settings
  configure do
    pagination default_limit: 25, max_limit: 100
    filtering allow: [:name, :email, :active]
    sorting allow: [:name, :created_at, :updated_at]
  end

  crud except: [:destroy] do # Exclude dangerous operations
    index do |inputs|
      users = User.all
      users = users.where(active: true) if inputs[:filter_active]
      users = users.search(inputs[:search]) if inputs[:search]
      
      paginated_response(
        data: users.map(&:to_h),
        page: inputs[:page] || 1,
        per_page: inputs[:per_page] || 25,
        total: users.count
      )
    end
    
    show { |inputs| User.find(inputs[:id])&.to_h || halt(404) }
    
    create do |inputs|
      user = User.create!(inputs[:body])
      status 201
      location "/users/#{user.id}"
      user.to_h
    end
    
    update do |inputs|
      user = User.find(inputs[:id]) || halt(404)
      user.update!(inputs[:body])
      user.to_h
    end
  end
  
  # Custom endpoints with full inheritance of resource configuration
  custom :post, ':id/avatar' do |inputs|
    user = User.find(inputs[:id]) || halt(404)
    avatar = user.update_avatar(inputs[:body][:avatar_data])
    { avatar_url: avatar.url, updated_at: avatar.updated_at }
  end
  
  custom :get, 'search/advanced' do |inputs|
    # Advanced search with multiple criteria
    results = UserSearchService.advanced_search(inputs)
    { users: results.map(&:to_h), search_metadata: results.metadata }
  end
end
```

### 📖 Automatic Documentation

Your API documentation is always up-to-date:

- **Interactive Swagger UI**: Try endpoints directly from the browser
- **Complete OpenAPI 3.0**: Full specification with schemas, examples, security
- **TypeScript clients**: Auto-generated for frontend teams
- **Markdown docs**: Perfect for wikis and README files
- **CLI generation**: `rapitapir generate docs --format html`

## 🔧 Framework Integration

### Sinatra (Recommended)

**Option 1: SinatraRapiTapir Base Class**
```ruby
require 'rapitapir'

class MyAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'My API', version: '2.0.0')
    development_defaults!
  end
  # Enhanced HTTP verb DSL + T shortcut automatically available
end
```

**Option 2: Manual Extension**
```ruby
require 'rapitapir/sinatra/extension'

class MyAPI < Sinatra::Base
  register RapiTapir::Sinatra::Extension
  # Use full DSL manually...
end
```

### Rails Integration

```ruby
# app/controllers/api/base_controller.rb
class Api::BaseController < ApplicationController
  include RapiTapir::Server::Rails::ControllerBase
  
  rapitapir do
    info(title: 'Rails API', version: '1.0.0')
    bearer_auth :jwt
  end
end

# app/controllers/api/users_controller.rb
class Api::UsersController < Api::BaseController
  endpoint(
    GET('/users')
      .summary('List users')
      .ok(T.array(USER_SCHEMA))
      .build
  ) { User.all.map(&:to_h) }
end
```

### Rack Applications

```ruby
require 'rapitapir/server/rack_adapter'

class MyRackApp
  include RapiTapir::Server::RackAdapter
  
  def initialize
    register_endpoints
  end
  
  private
  
  def register_endpoints
    endpoint(GET('/status').ok(T.hash({ "status" => T.string })).build) do
      { status: 'ok' }
    end
  end
end
```

## ☁️ Serverless Deployment

RapiTapir APIs can be deployed as serverless functions across all major cloud providers with zero configuration changes. The same SinatraRapiTapir code runs seamlessly on AWS Lambda, Google Cloud Functions, Azure Functions, and Vercel.

### 🚀 AWS Lambda

```ruby
require 'rapitapir'

class ServerlessAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'Serverless API', version: '1.0.0')
    development_defaults!
  end

  endpoint(GET('/hello').query(:name, T.string).ok(T.hash({"message" => T.string})).build) do |inputs|
    { message: "Hello from Lambda, #{inputs[:name]}!" }
  end
end

# Lambda handler
def lambda_handler(event:, context:)
  rack_env = build_rack_env_from_api_gateway(event, context)
  app = ServerlessAPI.new
  status, headers, body = app.call(rack_env)
  build_api_gateway_response(status, headers, body)
end
```

**Deploy with AWS SAM**:
```bash
sam build && sam deploy
```

### ☁️ Google Cloud Functions

```ruby
require 'functions_framework'

FunctionsFramework.http('my_api') do |request|
  rack_env = build_rack_env_from_cloud_functions(request)
  app = ServerlessAPI.new
  app.call(rack_env)
end
```

**Deploy**:
```bash
gcloud functions deploy my-api --runtime ruby32 --trigger-http
```

### 🌐 Vercel Edge Functions

```ruby
def handler(request:, response:)
  rack_env = build_rack_env_from_vercel(request)
  app = ServerlessAPI.new
  status, headers, body = app.call(rack_env)
  
  response.status = status
  headers.each { |k, v| response[k] = v }
  response.write(body.join)
end
```

**Deploy**:
```bash
vercel --prod
```

### Key Benefits

- **🚀 Zero Cold Start Impact**: Optimized for fast function startup
- **💰 Cost Effective**: Pay only for actual requests
- **🌍 Global Scale**: Deploy to edge locations worldwide  
- **🔒 Built-in Security**: Leverage cloud provider security
- **📊 Native Monitoring**: Integrate with cloud monitoring

### Complete Examples

See [examples/serverless/](examples/serverless/) for production-ready examples including:

- **AWS Lambda + API Gateway**: Full SAM template with DynamoDB
- **Google Cloud Functions**: With Firestore integration
- **Azure Functions**: With Cosmos DB and Service Bus
- **Vercel Edge**: With global edge caching
- **Multi-cloud deployment**: GitHub Actions workflows

## 🛡️ Production Features

### 🔐 Authentication & Authorization

```ruby
class SecureAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'Secure API', version: '2.0.0')
    
    # Multiple auth schemes supported
    bearer_auth :api_key, realm: 'API'
    oauth2_auth0 :auth0, domain: ENV['AUTH0_DOMAIN'], audience: ENV['AUTH0_AUDIENCE']
    basic_auth :admin, realm: 'Admin Panel'
    
    production_defaults! # Security headers, rate limiting, HTTPS enforcement
  end

  # Scope-based protection
  protect_with_oauth2 scopes: ['api:read'] do
    endpoint(GET('/protected/data').ok(T.array(T.hash({}))).build) { ProtectedData.all }
  end
  
  # Fine-grained permissions
  endpoint(
    DELETE('/admin/users/:id')
      .path_param(:id, T.integer)
      .bearer_auth(scopes: ['admin', 'users:delete'])
      .ok(T.hash({ "message" => T.string }))
      .build
  ) do |inputs|
    require_scope!('admin') # Additional runtime check
    UserService.delete(inputs[:id])
    { message: 'User deleted successfully' }
  end
end
```

### 📊 Observability & Monitoring

```ruby
class MonitoredAPI < SinatraRapiTapir
  rapitapir do
    info(title: 'Production API', version: '2.0.0')
    
    enable_observability do |config|
      # Health checks with custom probes
      config.health_checks.enable(path: '/health')
      config.health_checks.add_check('database') { Database.healthy? }
      config.health_checks.add_check('redis') { Redis.current.ping == 'PONG' }
      
      # OpenTelemetry integration
      config.tracing.enable_opentelemetry(
        service_name: 'my-api',
        exporters: [:honeycomb, :jaeger],
        sample_rate: 0.1
      )
      
      # Prometheus metrics
      config.metrics.enable_prometheus(
        namespace: 'my_api',
        path: '/metrics'
      )
      
      # Structured logging
      config.logging.enable_structured(format: :json)
    end
  end

  # Endpoints with observability
  endpoint(
    GET('/monitored-endpoint')
      .with_metrics('endpoint_requests', labels: { operation: 'get' })
      .with_tracing('fetch_data')
      .ok(T.hash({}))
      .build
  ) do
    # Custom spans and metrics automatically collected
    { data: 'response' }
  end
end
```

### 🔒 Security Middleware

Built-in security features for production deployments:

```ruby
# Automatic security middleware
use RapiTapir::Server::Middleware::SecurityHeaders
use RapiTapir::Server::Middleware::RateLimit, requests_per_minute: 100
use RapiTapir::Server::Middleware::CORS, origins: ['https://myapp.com']
use RapiTapir::Server::Middleware::RequestValidation
```

## 🤖 AI Integration Features

### LLM Instruction Generation

Generate context-aware instructions for any endpoint:

```ruby
# Generate instructions for different AI purposes
generator = RapiTapir::AI::LLMInstruction::Generator.new

# Validation instructions
validation_prompt = generator.generate_instructions(
  endpoint: my_endpoint,
  purpose: :validation
)

# Documentation instructions  
docs_prompt = generator.generate_instructions(
  endpoint: my_endpoint,
  purpose: :documentation
)

# Test generation instructions
test_prompt = generator.generate_instructions(
  endpoint: my_endpoint, 
  purpose: :testing
)
```

### RAG (Retrieval-Augmented Generation)

Enable semantic search and context-aware responses:

```ruby
endpoint(
  GET('/books/semantic-search')
    .query(:query, T.string)
    .enable_rag(
      retrieval_backend: :memory, # or :elasticsearch, :postgresql
      llm_provider: :openai,
      context_window: 4000
    )
    .ok(T.hash({
      "results" => T.array(BOOK_SCHEMA),
      "context" => T.string,
      "confidence" => T.float
    }))
    .build
) do |inputs|
  # RAG context automatically injected
  rag_enhanced_search(inputs[:query], context: rag_context)
end
```

### Model Context Protocol (MCP)

Export your API for AI agent consumption:

```ruby
# Export MCP-compatible JSON
exporter = RapiTapir::AI::MCP::Exporter.new(rapitapir_endpoints)
mcp_json = exporter.export_json(pretty: true)

# CLI export
# rapitapir mcp export --output api-context.json
```

## 🎨 Complete Examples

### 📚 Library Management System

A comprehensive example showcasing all features:

```ruby
require 'rapitapir'

class LibraryAPI < SinatraRapiTapir
  rapitapir do
    info(
      title: 'Library Management System',
      description: 'Complete library API with AI, auth, and observability',
      version: '2.0.0',
      contact: { name: 'API Team', email: 'api@library.com' }
    )
    
    # Auth configuration
    oauth2_auth0 :auth0,
      domain: ENV['AUTH0_DOMAIN'],
      audience: ENV['AUTH0_AUDIENCE']
    
    # Observability
    enable_observability do |config|
      config.health_checks.enable
      config.tracing.enable_opentelemetry(service_name: 'library-api')
      config.metrics.enable_prometheus
    end
    
    production_defaults!
  end

  # Schemas
  BOOK_SCHEMA = T.hash({
    "id" => T.integer,
    "isbn" => T.string(pattern: /^\d{13}$/),
    "title" => T.string(min_length: 1, max_length: 500),
    "authors" => T.array(T.string),
    "published_date" => T.date,
    "genres" => T.array(T.string),
    "available_copies" => T.integer(minimum: 0),
    "total_copies" => T.integer(minimum: 1),
    "metadata" => T.optional(T.hash({}))
  })

  MEMBER_SCHEMA = T.hash({
    "id" => T.integer,
    "email" => T.email,
    "name" => T.string(min_length: 1),
    "member_since" => T.date,
    "active" => T.boolean,
    "borrowed_books" => T.array(T.integer)
  })

  # Public endpoints
  endpoint(
    GET('/books/search')
      .query(:q, T.string(min_length: 1), description: 'Search query')
      .query(:ai_enhanced, T.optional(T.boolean), description: 'Use AI semantic search')
      .summary('Search books with optional AI enhancement')
      .tags('Books', 'Search')
      .ok(T.hash({
        "books" => T.array(BOOK_SCHEMA),
        "total" => T.integer,
        "ai_enhanced" => T.boolean
      }))
      .enable_rag
      .enable_mcp
      .build
  ) do |inputs|
    if inputs[:ai_enhanced]
      results = AIBookSearch.semantic_search(inputs[:q], context: rag_context)
    else
      results = Book.search(inputs[:q])
    end
    
    {
      books: results.map(&:to_h),
      total: results.count,
      ai_enhanced: !!inputs[:ai_enhanced]
    }
  end

  # Protected member endpoints
  protect_with_oauth2 scopes: ['library:read'] do
    api_resource '/books', schema: BOOK_SCHEMA do
      crud only: [:index, :show] do
        index { Book.available.map(&:to_h) }
        show { |inputs| Book.find(inputs[:id])&.to_h || halt(404) }
      end
      
      custom :post, ':id/reserve' do |inputs|
        book = Book.find(inputs[:id]) || halt(404)
        member = current_member
        
        reservation = ReservationService.create(book: book, member: member)
        { reservation_id: reservation.id, expires_at: reservation.expires_at }
      end
    end

    endpoint(
      GET('/members/me/profile')
        .summary('Get current member profile')
        .bearer_auth(scopes: ['profile:read'])
        .ok(MEMBER_SCHEMA)
        .build
    ) { current_member.to_h }
  end

  # Admin endpoints
  protect_with_oauth2 scopes: ['library:admin'] do
    api_resource '/admin/books', schema: BOOK_SCHEMA do
      crud do
        index { Book.all.map(&:to_h) }
        show { |inputs| Book.find(inputs[:id])&.to_h || halt(404) }
        create { |inputs| Book.create!(inputs[:body]).to_h }
        update { |inputs| Book.update!(inputs[:id], inputs[:body]).to_h }
        destroy { |inputs| Book.destroy(inputs[:id]); status 204 }
      end
    end
    
    # AI-powered book recommendations
    endpoint(
      POST('/admin/ai/recommend-acquisitions')
        .body(T.hash({
          "budget" => T.float(minimum: 0),
          "categories" => T.optional(T.array(T.string)),
          "member_preferences" => T.optional(T.boolean)
        }))
        .summary('Get AI-powered book acquisition recommendations')
        .tags('Admin', 'AI', 'Recommendations')
        .ok(T.hash({
          "recommendations" => T.array(T.hash({
            "title" => T.string,
            "author" => T.string,
            "estimated_cost" => T.float,
            "demand_score" => T.float,
            "reasoning" => T.string
          })),
          "total_estimated_cost" => T.float,
          "confidence" => T.float
        }))
        .enable_llm_instructions(purpose: :completion)
        .build
    ) do |inputs|
      recommendations = AIAcquisitionService.recommend(
        budget: inputs[:budget],
        categories: inputs[:categories],
        consider_member_preferences: inputs[:member_preferences],
        context: library_context
      )
      
      {
        recommendations: recommendations[:items],
        total_estimated_cost: recommendations[:total_cost],
        confidence: recommendations[:confidence_score]
      }
    end
  end

  run! if __FILE__ == $0
end
```

### 🏥 Healthcare API Example

```ruby
class HealthcareAPI < SinatraRapiTapir
  rapitapir do
    info(
      title: 'Healthcare Management API',
      description: 'HIPAA-compliant healthcare API with AI diagnostics',
      version: '2.0.0'
    )
    
    # Strict security for healthcare
    bearer_auth :jwt, realm: 'Healthcare'
    
    enable_observability do |config|
      config.health_checks.enable
      config.tracing.enable_opentelemetry(
        service_name: 'healthcare-api',
        compliance_mode: :hipaa
      )
      config.logging.enable_structured(
        format: :json,
        exclude_fields: [:ssn, :medical_record_number] # PII protection
      )
    end
    
    production_defaults!
  end

  PATIENT_SCHEMA = T.hash({
    "id" => T.string, # UUID for privacy
    "name" => T.hash({
      "first" => T.string,
      "last" => T.string
    }),
    "date_of_birth" => T.date,
    "medical_record_number" => T.string,
    "insurance" => T.optional(T.hash({}))
  })

  # AI-powered diagnostic assistance
  endpoint(
    POST('/diagnostics/analyze')
      .body(T.hash({
        "patient_id" => T.string,
        "symptoms" => T.array(T.string),
        "vital_signs" => T.hash({
          "temperature" => T.optional(T.float),
          "blood_pressure" => T.optional(T.string),
          "heart_rate" => T.optional(T.integer)
        }),
        "medical_history" => T.optional(T.array(T.string))
      }))
      .summary('AI-assisted diagnostic analysis')
      .bearer_auth(scopes: ['diagnostics:read', 'ai:analyze'])
      .tags('Diagnostics', 'AI')
      .ok(T.hash({
        "analysis" => T.hash({
          "suggested_conditions" => T.array(T.hash({
            "condition" => T.string,
            "confidence" => T.float,
            "reasoning" => T.string
          })),
          "recommended_tests" => T.array(T.string),
          "urgency_level" => T.string(enum: %w[low medium high critical])
        }),
        "disclaimer" => T.string,
        "generated_at" => T.datetime
      }))
      .enable_llm_instructions(purpose: :analysis)
      .build
  ) do |inputs|
    # Verify provider permissions
    require_scope!('diagnostics:read')
    
    # AI diagnostic analysis with medical context
    analysis = MedicalAI.analyze_symptoms(
      patient_id: inputs[:patient_id],
      symptoms: inputs[:symptoms],
      vital_signs: inputs[:vital_signs],
      medical_history: inputs[:medical_history],
      provider_context: current_provider_context
    )
    
    {
      analysis: analysis,
      disclaimer: "This analysis is for informational purposes only and should not replace professional medical judgment.",
      generated_at: Time.now
    }
  end

  run! if __FILE__ == $0
end
```

## 📚 Documentation

### Core Guides

- **[Getting Started Guide](examples/working_simple_example.rb)** - Your first RapiTapir API in 5 minutes
- **[SinatraRapiTapir Base Class](docs/sinatra_rapitapir.md)** - Zero-boilerplate API creation
- **[Enhanced HTTP DSL](docs/endpoint-definition.md)** - Complete endpoint definition guide
- **[Type System & T Shortcut](docs/type_shortcuts.md)** - All available types and validations
- **[Resource Builder](docs/RAILS_INTEGRATION_IMPLEMENTATION.md)** - RESTful CRUD with minimal code

### Advanced Features

- **[AI Integration](docs/auto-derivation.md)** - LLM instructions, RAG pipelines, MCP export
- **[Authentication & Security](examples/authentication_example.rb)** - OAuth2, JWT, scopes, and Auth0
- **[Observability](docs/observability.md)** - OpenTelemetry, health checks, metrics
- **[CLI Toolkit](docs/blueprint.md)** - Complete command-line development workflow

### Framework Integration

- **[Sinatra Extension](docs/SINATRA_EXTENSION.md)** - Detailed Sinatra integration guide
- **[Rails Integration](docs/RAILS_INTEGRATION_IMPLEMENTATION.md)** - Controller-based Rails APIs
- **[Rack Applications](docs/implementation-status.md)** - Direct Rack integration

### Examples & Templates

Explore our comprehensive examples directory:

- **[Hello World](examples/hello_world.rb)** - 30-second minimal example
- **[Enterprise API](examples/enterprise_rapitapir_api.rb)** - Production-ready with all features
- **[Serverless Deployment](examples/serverless/)** - AWS Lambda, Google Cloud Functions, Azure Functions, Vercel
- **[OAuth2 + Auth0](examples/oauth2/)** - Complete authentication examples
- **[AI-Powered APIs](examples/auto_derivation_ruby_friendly.rb)** - LLM and RAG integration
- **[Observability Setup](examples/observability/)** - Monitoring and health checks
- **[CLI Examples](examples/cli/)** - Command-line toolkit usage

## Architecture Decision Records (ADRs)

Key architectural decisions are tracked in `docs/adr/`:

- ADR index and guidelines: [docs/adr/README.md](docs/adr/README.md)
- Template: [docs/adr/template.md](docs/adr/template.md)

Initial ADRs:

- [ADR-0001: Base class strategy (SinatraRapiTapir) vs manual extension](docs/adr/0001-base-class-strategy.md)
- [ADR-0002: Type shortcut (T) and type system boundaries](docs/adr/0002-type-shortcut-and-type-system.md)
- [ADR-0003: OpenAPI source-of-truth and doc generation flow](docs/adr/0003-openapi-source-of-truth.md)
- [ADR-0004: Client generation target (TypeScript first) and interface conventions](docs/adr/0004-client-generation-typescript-first.md)
- [ADR-0005: Authentication architecture (schemes + helpers + middleware)](docs/adr/0005-auth-architecture.md)
- [ADR-0006: Observability defaults (health, logging, metrics/tracing hooks)](docs/adr/0006-observability-defaults.md)
- [ADR-0007: AI features scope (RAG/LLM/MCP) and maintainability boundaries](docs/adr/0007-ai-scope-and-boundaries.md)


## 🛠️ CLI Development Toolkit

RapiTapir includes a powerful CLI for streamlined development:

### Code Generation
```bash
# Generate OpenAPI specifications
rapitapir generate openapi --output api-spec.json --format json
rapitapir generate openapi --output api-spec.yaml --format yaml

# Generate TypeScript clients  
rapitapir generate client typescript --output client/api.ts
rapitapir generate client python --output client/api.py

# Generate documentation
rapitapir generate docs html --output docs/api.html
rapitapir generate docs markdown --output API.md
```

### AI-Powered Features
```bash
# Generate LLM instructions for specific endpoints
rapitapir llm generate --endpoint-id "get_users" --purpose validation
rapitapir llm generate --endpoint-id "create_book" --purpose testing

# Export LLM instructions for all endpoints
rapitapir llm export --format instructions --output ai-prompts/

# Test LLM instruction generation
rapitapir llm test --endpoint-file my_api.rb

# Export Model Context Protocol for AI agents
rapitapir mcp export --output mcp-context.json --format compact
```

### Development & Validation
```bash
# Validate endpoint definitions
rapitapir validate endpoints --file my_api.rb
rapitapir validate openapi --file api-spec.json

# Serve documentation and specs
rapitapir serve --port 3000 --docs-path /documentation
rapitapir docs --serve --port 8080 --watch

# Project scaffolding (coming soon)
rapitapir new my-api --template sinatra-ai
rapitapir generate scaffold books --with-auth --with-observability
```

### Installation & Setup

```bash
# Install the gem
gem install rapitapir

# Or add to Gemfile
echo 'gem "rapitapir"' >> Gemfile
bundle install

# Verify installation
rapitapir --version
rapitapir --help
```

## 🧪 Testing & Quality

RapiTapir includes comprehensive testing utilities and maintains high code quality:

### Test Your APIs
```ruby
# Validate endpoint definitions
RapiTapir::CLI::Validator.new(endpoints).validate

# Generate test fixtures from schemas
test_user = RapiTapir::Testing.generate_fixture(USER_SCHEMA)
test_data = RapiTapir::Testing.generate_fixtures(BOOK_SCHEMA, count: 10)

# Test endpoint types and validation
endpoint.validate!({ name: "test", age: 25 }) # Returns validated data
```

### Quality Metrics
- **643 tests passing** with comprehensive coverage
- **67.67% line coverage** across the entire codebase  
- **RuboCop compliance** with zero style violations
- **Zero security vulnerabilities** in dependencies
- **Continuous integration** with GitHub Actions

### Run Tests Locally
```bash
# Clone the repository
git clone https://github.com/riccardomerolla/rapitapir.git
cd rapitapir

# Install dependencies
bundle install

# Run the test suite
bundle exec rspec

# Check code style
rubocop

# View coverage report
open coverage/index.html
```

## 🤝 Contributing

We love contributions! RapiTapir thrives on community input and collaboration.

### Quick Start Contributing
```bash
git clone https://github.com/riccardomerolla/rapitapir.git
cd rapitapir
bundle install
bundle exec rspec # Ensure all tests pass
```

### Ways to Contribute
- **🐛 Bug Reports**: [Open an issue](https://github.com/riccardomerolla/rapitapir/issues/new)
- **💡 Feature Requests**: [Start a discussion](https://github.com/riccardomerolla/rapitapir/discussions)
- **📖 Documentation**: Improve guides, examples, and API docs
- **🧪 Tests**: Add test coverage for edge cases
- **🎨 Examples**: Create real-world API examples
- **🔌 Integrations**: Build plugins for other frameworks

### Development Roadmap

**Current Focus (v2.1)**:
- Enhanced AI features and LLM provider support
- Advanced authentication patterns
- Performance optimizations and caching
- Extended CLI functionality

**Upcoming (v3.0)**:
- GraphQL integration alongside REST
- gRPC support for high-performance APIs  
- Advanced plugin ecosystem
- Multi-language client generation

See our [Contributing Guide](CONTRIBUTING.md) for detailed guidelines.

## 🙋‍♂️ Support & Community

### Get Help
- **🐛 Bug Reports**: [GitHub Issues](https://github.com/riccardomerolla/rapitapir/issues)
- **� Questions & Discussions**: [GitHub Discussions](https://github.com/riccardomerolla/rapitapir/discussions)
- **📧 Direct Contact**: riccardo.merolla@gmail.com
- **📖 Documentation**: Comprehensive guides in the [docs/](docs/) directory

### Community
- **⭐ Star the Project**: Show your support on [GitHub](https://github.com/riccardomerolla/rapitapir)
- **🔗 Share**: Help others discover RapiTapir
- **🤝 Contribute**: Join the growing community of contributors

---

## 📜 License

RapiTapir is released under the [MIT License](LICENSE). Use it freely in personal and commercial projects.

## 🙏 Acknowledgments

RapiTapir is inspired by excellent projects in the API development space:

- **[Scala Tapir](https://github.com/softwaremill/tapir)** - Type-safe endpoint definitions that inspired our DSL
- **[FastAPI](https://fastapi.tiangolo.com/)** - Automatic documentation and validation patterns
- **[Ruby on Rails](https://rubyonrails.org/)** - Convention over configuration philosophy
- **[Sinatra](http://sinatrarb.com/)** - Minimalist web framework elegance

Special thanks to the Ruby and Sinatra communities for their ongoing support and feedback.

---

**RapiTapir 🦙** - *APIs so fast, clean, and intelligent, they practically run wild!* ⚡�

**Built with ❤️ for the Ruby community**
