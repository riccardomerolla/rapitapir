# frozen_string_literal: true

# Enterprise-grade Sinatra API with RapiTapir - Using SinatraAdapter
#
# This example demonstrates a production-ready Sinatra application with:
# - Bearer Token Authentication
# - Auto-generated OpenAPI 3.0 documentation from RapiTapir endpoint definitions
# - Request/Response validation with SinatraAdapter
# - Error handling
# - Rate limiting
# - CORS support
# - Security headers

require 'sinatra/base'
require 'json'
require 'rack'
require_relative '../lib/rapitapir'
require_relative '../lib/rapitapir/server/sinatra_adapter'

# Sample User Database (In production, use a real database)
class UserDatabase
  USERS = {
    'user-token-123' => {
      id: 1,
      name: 'John Doe',
      email: 'john.doe@example.com',
      role: 'user',
      scopes: %w[read write]
    },
    'admin-token-456' => {
      id: 2,
      name: 'Jane Admin',
      email: 'jane.admin@example.com',
      role: 'admin',
      scopes: %w[read write admin delete]
    },
    'readonly-token-789' => {
      id: 3,
      name: 'Bob Reader',
      email: 'bob.reader@example.com',
      role: 'readonly',
      scopes: ['read']
    }
  }.freeze

  def self.find_by_token(token)
    USERS[token]
  end

  def self.all_users
    USERS.values
  end

  def self.find_by_id(id)
    USERS.values.find { |user| user[:id] == id.to_i }
  end
end

# Task Database (In production, use a real database)
class TaskDatabase
  @@tasks = [
    { id: 1, title: 'Setup CI/CD Pipeline', description: 'Configure automated testing and deployment',
      status: 'in_progress', assignee_id: 1, created_at: Time.now - 86_400 },
    { id: 2, title: 'Review Security Audit', description: 'Complete quarterly security review', status: 'pending',
      assignee_id: 2, created_at: Time.now - 3600 },
    { id: 3, title: 'Update Documentation', description: 'Refresh API documentation', status: 'completed',
      assignee_id: 1, created_at: Time.now - 172_800 }
  ]
  @@next_id = 4

  def self.all
    @@tasks
  end

  def self.find(id)
    @@tasks.find { |task| task[:id] == id.to_i }
  end

  def self.create(attrs)
    task = attrs.merge(id: @@next_id, created_at: Time.now)
    @@next_id += 1
    @@tasks << task
    task
  end

  def self.update(id, attrs)
    task = find(id)
    return nil unless task

    attrs.each { |key, value| task[key] = value }
    task[:updated_at] = Time.now
    task
  end

  def self.delete(id)
    @@tasks.reject! { |task| task[:id] == id.to_i }
  end

  def self.by_assignee(assignee_id)
    @@tasks.select { |task| task[:assignee_id] == assignee_id.to_i }
  end
end

# RapiTapir Endpoint Definitions
module TaskAPI
  extend RapiTapir::DSL

  # Define schemas using RapiTapir types
  TASK_SCHEMA = RapiTapir::Types.hash({
                                        'id' => RapiTapir::Types.integer,
                                        'title' => RapiTapir::Types.string,
                                        'description' => RapiTapir::Types.string,
                                        'status' => RapiTapir::Types.string,
                                        'assignee_id' => RapiTapir::Types.integer,
                                        'created_at' => RapiTapir::Types.string,
                                        'updated_at' => RapiTapir::Types.optional(RapiTapir::Types.string)
                                      })

  TASK_CREATE_SCHEMA = RapiTapir::Types.hash({
                                               'title' => RapiTapir::Types.string,
                                               'description' => RapiTapir::Types.string,
                                               'status' => RapiTapir::Types.optional(RapiTapir::Types.string),
                                               'assignee_id' => RapiTapir::Types.integer
                                             })

  TASK_UPDATE_SCHEMA = RapiTapir::Types.hash({
                                               'title' => RapiTapir::Types.optional(RapiTapir::Types.string),
                                               'description' => RapiTapir::Types.optional(RapiTapir::Types.string),
                                               'status' => RapiTapir::Types.optional(RapiTapir::Types.string),
                                               'assignee_id' => RapiTapir::Types.optional(RapiTapir::Types.integer)
                                             })

  USER_SCHEMA = RapiTapir::Types.hash({
                                        'id' => RapiTapir::Types.integer,
                                        'name' => RapiTapir::Types.string,
                                        'email' => RapiTapir::Types.string,
                                        'role' => RapiTapir::Types.string,
                                        'scopes' => RapiTapir::Types.array(RapiTapir::Types.string)
                                      })

  ERROR_SCHEMA = RapiTapir::Types.hash({
                                         'error' => RapiTapir::Types.string
                                       })

  HEALTH_SCHEMA = RapiTapir::Types.hash({
                                          'status' => RapiTapir::Types.string,
                                          'timestamp' => RapiTapir::Types.string,
                                          'version' => RapiTapir::Types.string,
                                          'uptime' => RapiTapir::Types.integer,
                                          'authentication' => RapiTapir::Types.string,
                                          'features' => RapiTapir::Types.array(RapiTapir::Types.string)
                                        })

  # Define all API endpoints using RapiTapir DSL
  def self.endpoints
    @endpoints ||= [
      # Health check endpoint (public)
      RapiTapir.get('/health')
               .summary('Health check')
               .description('Returns the health status of the API')
               .ok(HEALTH_SCHEMA)
               .build,

      # List tasks endpoint
      RapiTapir.get('/api/v1/tasks')
               .summary('List all tasks')
               .description('Retrieve a list of all tasks in the system. Requires read permission.')
               .query(:status, RapiTapir::Types.optional(RapiTapir::Types.string),
                      description: 'Filter by task status')
               .query(:assignee_id, RapiTapir::Types.optional(RapiTapir::Types.integer),
                      description: 'Filter by assignee ID')
               .query(:limit, RapiTapir::Types.optional(RapiTapir::Types.integer),
                      description: 'Maximum number of results')
               .query(:offset, RapiTapir::Types.optional(RapiTapir::Types.integer),
                      description: 'Number of results to skip')
               .ok(RapiTapir::Types.array(TASK_SCHEMA))
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .error_response(403, ERROR_SCHEMA, description: 'Insufficient permissions')
               .build,

      # Get specific task endpoint
      RapiTapir.get('/api/v1/tasks/:id')
               .summary('Get a specific task')
               .description('Retrieve details of a specific task by ID. Requires read permission.')
               .path_param(:id, RapiTapir::Types.integer, description: 'Task ID')
               .ok(TASK_SCHEMA)
               .error_response(404, ERROR_SCHEMA, description: 'Task not found')
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .build,

      # Create task endpoint
      RapiTapir.post('/api/v1/tasks')
               .summary('Create a new task')
               .description('Create a new task in the system. Requires write permission.')
               .json_body(TASK_CREATE_SCHEMA)
               .created(TASK_SCHEMA)
               .error_response(400, ERROR_SCHEMA, description: 'Validation error')
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .error_response(403, ERROR_SCHEMA, description: 'Insufficient permissions')
               .build,

      # Update task endpoint
      RapiTapir.put('/api/v1/tasks/:id')
               .summary('Update a task')
               .description('Update an existing task. Requires write permission.')
               .path_param(:id, RapiTapir::Types.integer, description: 'Task ID')
               .json_body(TASK_UPDATE_SCHEMA)
               .ok(TASK_SCHEMA)
               .error_response(404, ERROR_SCHEMA, description: 'Task not found')
               .error_response(400, ERROR_SCHEMA, description: 'Validation error')
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .error_response(403, ERROR_SCHEMA, description: 'Insufficient permissions')
               .build,

      # Delete task endpoint
      RapiTapir.delete('/api/v1/tasks/:id')
               .summary('Delete a task')
               .description('Delete a task from the system. Requires admin permission.')
               .path_param(:id, RapiTapir::Types.integer, description: 'Task ID')
               .no_content(description: 'Task deleted successfully')
               .error_response(404, ERROR_SCHEMA, description: 'Task not found')
               .error_response(403, ERROR_SCHEMA, description: 'Admin permission required')
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .build,

      # User profile endpoint
      RapiTapir.get('/api/v1/profile')
               .summary('Get current user profile')
               .description('Retrieve the profile of the authenticated user')
               .ok(RapiTapir::Types.hash({
                                           'id' => RapiTapir::Types.integer,
                                           'name' => RapiTapir::Types.string,
                                           'email' => RapiTapir::Types.string,
                                           'role' => RapiTapir::Types.string,
                                           'scopes' => RapiTapir::Types.array(RapiTapir::Types.string),
                                           'tasks' => RapiTapir::Types.array(RapiTapir::Types.hash({
                                                                                                     'id' => RapiTapir::Types.integer,
                                                                                                     'title' => RapiTapir::Types.string,
                                                                                                     'status' => RapiTapir::Types.string
                                                                                                   }))
                                         }))
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .build,

      # Admin users endpoint
      RapiTapir.get('/api/v1/admin/users')
               .summary('List all users (admin only)')
               .description('Retrieve a list of all users in the system. Requires admin permission.')
               .ok(RapiTapir::Types.array(USER_SCHEMA))
               .error_response(401, ERROR_SCHEMA, description: 'Authentication required')
               .error_response(403, ERROR_SCHEMA, description: 'Admin permission required')
               .build
    ]
  end

  # Generate OpenAPI specification from RapiTapir endpoints
  def self.openapi_spec
    @openapi_spec ||= begin
      require_relative '../lib/rapitapir/openapi/schema_generator'

      generator = RapiTapir::OpenAPI::SchemaGenerator.new(
        endpoints: endpoints,
        info: {
          title: 'Enterprise Task Management API',
          description: 'A production-ready task management API with authentication and authorization',
          version: '1.0.0',
          contact: {
            name: 'API Support',
            email: 'api-support@example.com',
            url: 'https://example.com/support'
          },
          license: {
            name: 'MIT',
            url: 'https://opensource.org/licenses/MIT'
          }
        },
        servers: [
          {
            url: 'http://localhost:4567',
            description: 'Development server'
          },
          {
            url: 'https://api.example.com',
            description: 'Production server'
          }
        ]
      )

      # Add security schemes to the spec
      spec = generator.generate
      spec[:components] ||= {}
      spec[:components][:securitySchemes] = {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'Token',
          description: 'Enter your bearer token (e.g., user-token-123)'
        }
      }

      # Add security requirement to all endpoints except health
      spec[:paths].each do |path, methods|
        next if path == '/health'

        methods.each_value do |operation|
          operation[:security] = [{ bearerAuth: [] }]
        end
      end

      spec
    end
  end
end

# Main Sinatra Application
class EnterpriseTaskAPI < Sinatra::Base
  set :show_exceptions, false
  set :raise_errors, false
  set :dump_errors, false

  # Setup authentication scheme
  bearer_auth = RapiTapir::Auth.bearer_token(:bearer, {
                                               realm: 'Enterprise Task Management API',
                                               token_validator: proc do |token|
                                                 user = UserDatabase.find_by_token(token)
                                                 next nil unless user

                                                 {
                                                   user: user,
                                                   scopes: user[:scopes]
                                                 }
                                               end
                                             })

  auth_schemes = { bearer: bearer_auth }

  # Setup middleware stack
  use RapiTapir::Auth::Middleware::SecurityHeadersMiddleware
  use RapiTapir::Auth::Middleware::CorsMiddleware, {
    allowed_origins: ['http://localhost:3000', 'https://app.example.com'],
    allowed_methods: %w[GET POST PUT DELETE PATCH OPTIONS],
    allowed_headers: %w[Authorization Content-Type Accept],
    allow_credentials: true
  }
  use RapiTapir::Auth::Middleware::RateLimitingMiddleware, {
    requests_per_minute: 100,
    requests_per_hour: 2000
  }
  use RapiTapir::Auth::Middleware::AuthenticationMiddleware, auth_schemes

  # --- helpers removed: see class-level json_response/enforce!/format_task ---

  def self.format_task(task)
    task_copy = task.dup
    task_copy[:created_at] = task_copy[:created_at].iso8601 if task_copy[:created_at]
    task_copy[:updated_at] = task_copy[:updated_at].iso8601 if task_copy[:updated_at]
    task_copy
  end

  private

  def self.setup_rapitapir_endpoints
    # Bind the adapter to the app class: route DSL (get/post/...) is a class
    # method, and handlers instance_exec'd against the class can use the
    # class-level helpers below (json_response, enforce!, format_task).
    adapter = RapiTapir::Server::SinatraAdapter.new(self)

    # Register all endpoints using the adapter
    TaskAPI.endpoints.each do |endpoint|
      adapter.register_endpoint(endpoint, get_endpoint_handler(endpoint))
    end

    adapter
  end

  # Helper methods (class-level; the adapter runs handlers in class context).
  # Handlers return either a plain data hash (200 + JSON) or a
  # [status, headers, body] triple, which the adapter translates directly.
  def self.json_response(status, data)
    [status, { 'Content-Type' => 'application/json' }, JSON.generate(data)]
  end

  # Returns nil when the scope is satisfied, otherwise a 401/403 response triple.
  def self.enforce!(scope)
    return json_response(401, { error: 'Authentication required' }) unless RapiTapir::Auth.authenticated?
    return json_response(403, { error: "#{scope.capitalize} permission required" }) unless RapiTapir::Auth.scope?(scope)

    nil
  end

  def self.get_endpoint_handler(endpoint)
    case endpoint.path
    when '/health'
      proc do |_inputs|
        {
          status: 'healthy',
          timestamp: Time.now.iso8601,
          version: '1.0.0',
          uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i,
          authentication: 'Bearer Token',
          features: ['Rate Limiting', 'CORS', 'Security Headers', 'Auto-generated OpenAPI 3.0', 'RapiTapir DSL']
        }
      end

    when '/api/v1/tasks'
      if endpoint.method == :get
        proc do |inputs|
          guard = enforce!('read')
          return guard if guard

          tasks = TaskDatabase.all

          # Apply filters
          tasks = tasks.select { |task| task[:status] == inputs[:status] } if inputs[:status]

          tasks = tasks.select { |task| task[:assignee_id] == inputs[:assignee_id] } if inputs[:assignee_id]

          # Apply pagination
          limit = inputs[:limit] || 50
          offset = inputs[:offset] || 0
          tasks = tasks.drop(offset).take(limit)

          # Format timestamps
          tasks.map { |task| format_task(task) }
        end
      else # POST
        proc do |inputs|
          guard = enforce!('write')
          return guard if guard

          body = inputs[:body] || {}

          # Validate required fields - now handled by RapiTapir type validation
          # Create task
          task_data = {
            title: body['title'],
            description: body['description'],
            status: body['status'] || 'pending',
            assignee_id: body['assignee_id']
          }

          task = TaskDatabase.create(task_data)
          format_task(task)
        end
      end

    when '/api/v1/tasks/:id'
      case endpoint.method
      when :get
        proc do |inputs|
          guard = enforce!('read')
          return guard if guard

          task = TaskDatabase.find(inputs[:id])
          return json_response(404, { error: 'Task not found' }) unless task

          # Enrich with assignee details
          assignee = UserDatabase.find_by_id(task[:assignee_id])
          task_with_assignee = format_task(task)
          task_with_assignee[:assignee] = if assignee
                                            {
                                              id: assignee[:id],
                                              name: assignee[:name],
                                              email: assignee[:email]
                                            }
                                          end

          task_with_assignee
        end
      when :put
        proc do |inputs|
          guard = enforce!('write')
          return guard if guard

          task = TaskDatabase.find(inputs[:id])
          return json_response(404, { error: 'Task not found' }) unless task

          body = inputs[:body] || {}
          update_data = {}

          # Prepare update data - validation handled by RapiTapir
          update_data[:title] = body['title'] if body['title']
          update_data[:description] = body['description'] if body['description']
          update_data[:status] = body['status'] if body['status']
          update_data[:assignee_id] = body['assignee_id'] if body['assignee_id']

          # Update task
          updated_task = TaskDatabase.update(inputs[:id], update_data)
          format_task(updated_task)
        end
      when :delete
        proc do |inputs|
          guard = enforce!('admin')
          return guard if guard

          task = TaskDatabase.find(inputs[:id])
          return json_response(404, { error: 'Task not found' }) unless task

          TaskDatabase.delete(inputs[:id])
          [204, {}, '']
        end
      end

    when '/api/v1/profile'
      proc do |_inputs|
        guard = enforce!('read')
        return guard if guard

        current_user = RapiTapir::Auth.current_user

        # Get user's assigned tasks
        user_tasks = TaskDatabase.by_assignee(current_user[:id]).map do |task|
          {
            id: task[:id],
            title: task[:title],
            status: task[:status]
          }
        end

        profile = current_user.dup
        profile[:tasks] = user_tasks
        profile
      end

    when '/api/v1/admin/users'
      proc do |_inputs|
        guard = enforce!('admin')
        return guard if guard

        UserDatabase.all_users
      end

    else
      proc do |_inputs|
        json_response(404, { error: 'Endpoint not implemented' })
      end
    end
  end

  # OpenAPI Documentation endpoint - Auto-generated from RapiTapir endpoints
  get '/openapi.json' do
    content_type :json
    JSON.pretty_generate(TaskAPI.openapi_spec)
  end

  # Swagger UI endpoint
  get '/docs' do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Enterprise Task Management API - Documentation</title>
        <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
        <style>
          html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
          *, *:before, *:after { box-sizing: inherit; }
          body { margin:0; background: #fafafa; }
          .swagger-ui .topbar { display: none; }
          .info-banner {
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
            margin-bottom: 20px;
          }
          .info-banner h1 { margin: 0; font-size: 24px; }
          .info-banner p { margin: 10px 0 0 0; opacity: 0.9; }
        </style>
      </head>
      <body>
        <div class="info-banner">
          <h1>🚀 Enterprise Task Management API</h1>
          <p>Auto-generated from RapiTapir endpoint definitions with SinatraAdapter integration</p>
        </div>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
        <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
        <script>
          window.onload = function() {
            const ui = SwaggerUIBundle({
              url: '/openapi.json',
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              plugins: [
                SwaggerUIBundle.plugins.DownloadUrl
              ],
              layout: "StandaloneLayout",
              tryItOutEnabled: true,
              supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
              onComplete: function() {
                console.log('Swagger UI loaded successfully');
                console.log('OpenAPI spec auto-generated from RapiTapir endpoints');
                console.log('Endpoints handled by SinatraAdapter with full type validation');
              }
            });
          };
        </script>
      </body>
      </html>
    HTML
  end

  # Global error handler
  error do |e|
    content_type :json
    status 500
    JSON.generate({
                    error: 'Internal server error',
                    message: development? ? e.message : 'Something went wrong'
                  })
  end

  # 404 handler
  not_found do
    content_type :json
    JSON.generate({ error: 'Endpoint not found' })
  end

  # Start server info
  configure :development do
    puts "\n🚀 Enterprise Task Management API Starting..."
    puts '📚 API Documentation: http://localhost:4567/docs'
    puts '📋 OpenAPI Spec (Auto-generated): http://localhost:4567/openapi.json'
    puts '❤️  Health Check: http://localhost:4567/health'
    puts "\n🔑 Available Bearer Tokens:"
    puts '   User Token: user-token-123 (scopes: read, write)'
    puts '   Admin Token: admin-token-456 (scopes: read, write, admin, delete)'
    puts '   Read-only Token: readonly-token-789 (scopes: read)'
    puts "\n📖 Example API Calls:"
    puts "   curl -H 'Authorization: Bearer user-token-123' http://localhost:4567/api/v1/tasks"
    puts "   curl -H 'Authorization: Bearer admin-token-456' http://localhost:4567/api/v1/admin/users"
    puts "   curl -X POST -H 'Authorization: Bearer user-token-123' -H 'Content-Type: application/json' \\"
    puts "        -d '{\"title\":\"New Task\",\"description\":\"Test task\",\"assignee_id\":1}' \\"
    puts '        http://localhost:4567/api/v1/tasks'
    puts "\n✨ Features: SinatraAdapter, Bearer Auth, Rate Limiting, CORS, Security Headers"
    puts "🎯 RapiTapir: #{TaskAPI.endpoints.size} endpoints auto-registered with full type safety"
    puts '🔧 Architecture: Routes handled by SinatraAdapter with automatic input/output validation'
    puts ''
  end

  # Now that get_endpoint_handler is defined, wire up the adapter + routes
  setup_rapitapir_endpoints
end

# Start the server if this file is run directly
EnterpriseTaskAPI.run! if __FILE__ == $PROGRAM_NAME
