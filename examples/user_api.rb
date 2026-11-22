# frozen_string_literal: true

require 'date'
require_relative '../lib/rapitapir'

# Example: User Management API
module UserAPI
  # Shared type definitions
  USER_TYPE = RapiTapir::Types.hash({
    'id' => RapiTapir::Types.integer,
    'name' => RapiTapir::Types.string,
    'email' => RapiTapir::Types.string
  })

  USER_DETAIL_TYPE = RapiTapir::Types.hash({
    'id' => RapiTapir::Types.integer,
    'name' => RapiTapir::Types.string,
    'email' => RapiTapir::Types.string,
    'created_at' => RapiTapir::Types.datetime
  })

  CREATE_USER_TYPE = RapiTapir::Types.hash({
    'name' => RapiTapir::Types.string,
    'email' => RapiTapir::Types.string,
    'password' => RapiTapir::Types.string
  })

  LOGIN_TYPE = RapiTapir::Types.hash({
    'email' => RapiTapir::Types.string,
    'password' => RapiTapir::Types.string
  })

  LOGIN_RESULT_TYPE = RapiTapir::Types.hash({
    'user' => USER_TYPE,
    'token' => RapiTapir::Types.string,
    'expires_at' => RapiTapir::Types.datetime
  })

  ERROR_TYPE = RapiTapir::Types.hash({
    'error' => RapiTapir::Types.string
  })

  VALIDATION_ERROR_TYPE = RapiTapir::Types.hash({
    'error' => RapiTapir::Types.string,
    'validation_errors' => RapiTapir::Types.array(
      RapiTapir::Types.hash({
        'field' => RapiTapir::Types.string,
        'message' => RapiTapir::Types.string
      })
    )
  })

  USER_LIST_TYPE = RapiTapir::Types.hash({
    'users' => RapiTapir::Types.array(USER_TYPE),
    'total' => RapiTapir::Types.integer,
    'page' => RapiTapir::Types.integer,
    'limit' => RapiTapir::Types.integer
  })

  # GET /users - List all users
  LIST_USERS = RapiTapir.get('/users')
                        .query(:page, RapiTapir::Types.optional(RapiTapir::Types.integer))
                        .query(:limit, RapiTapir::Types.optional(RapiTapir::Types.integer))
                        .query(:search, RapiTapir::Types.optional(RapiTapir::Types.string))
                        .header(:authorization, RapiTapir::Types.string)
                        .ok(USER_LIST_TYPE)
                        .unauthorized(ERROR_TYPE)
                        .internal_server_error(ERROR_TYPE)
                        .description('Retrieve a paginated list of users')
                        .summary('List users')
                        .tags('users')
                        .build

  # GET /users/:id - Get specific user
  GET_USER = RapiTapir.get('/users/:id')
                      .path_param(:id, RapiTapir::Types.integer)
                      .header(:authorization, RapiTapir::Types.string)
                      .ok(USER_DETAIL_TYPE)
                      .unauthorized(ERROR_TYPE)
                      .not_found(ERROR_TYPE)
                      .internal_server_error(ERROR_TYPE)
                      .description('Retrieve a specific user by ID')
                      .summary('Get user')
                      .tags('users')
                      .build

  # POST /users - Create new user
  CREATE_USER = RapiTapir.post('/users')
                         .header(:authorization, RapiTapir::Types.string)
                         .json_body(CREATE_USER_TYPE)
                         .created(USER_DETAIL_TYPE)
                         .bad_request(ERROR_TYPE)
                         .unauthorized(ERROR_TYPE)
                         .unprocessable_entity(VALIDATION_ERROR_TYPE)
                         .internal_server_error(ERROR_TYPE)
                         .description('Create a new user account')
                         .summary('Create user')
                         .tags('users')
                         .build

  # PUT /users/:id - Update user
  UPDATE_USER = RapiTapir.put('/users/:id')
                         .path_param(:id, RapiTapir::Types.integer)
                         .header(:authorization, RapiTapir::Types.string)
                         .json_body(RapiTapir::Types.hash({
                                     'name' => RapiTapir::Types.string,
                                     'email' => RapiTapir::Types.string
                                   }))
                         .ok(RapiTapir::Types.hash({
                             'id' => RapiTapir::Types.integer,
                             'name' => RapiTapir::Types.string,
                             'email' => RapiTapir::Types.string,
                             'updated_at' => RapiTapir::Types.datetime
                           }))
                         .bad_request(ERROR_TYPE)
                         .unauthorized(ERROR_TYPE)
                         .not_found(ERROR_TYPE)
                         .unprocessable_entity(VALIDATION_ERROR_TYPE)
                         .internal_server_error(ERROR_TYPE)
                         .description('Update an existing user')
                         .summary('Update user')
                         .tags('users')
                         .build

  # DELETE /users/:id - Delete user
  DELETE_USER = RapiTapir.delete('/users/:id')
                         .path_param(:id, RapiTapir::Types.integer)
                         .header(:authorization, RapiTapir::Types.string)
                         .no_content
                         .unauthorized(ERROR_TYPE)
                         .not_found(ERROR_TYPE)
                         .internal_server_error(ERROR_TYPE)
                         .description('Delete a user account')
                         .summary('Delete user')
                         .tags('users')
                         .build

  # POST /users/login - User authentication
  LOGIN_USER = RapiTapir.post('/users/login')
                        .json_body(LOGIN_TYPE)
                        .ok(LOGIN_RESULT_TYPE)
                        .bad_request(ERROR_TYPE)
                        .unauthorized(ERROR_TYPE)
                        .internal_server_error(ERROR_TYPE)
                        .description('Authenticate user and return access token')
                        .summary('User login')
                        .tags('authentication')
                        .build

  # Example usage and validation
  def self.demo
    puts '=== RapiTapir User API Demo ==='
    puts

    # Example 1: Endpoint structure
    puts '1. Endpoint structure:'
    puts '  GET /users:'
    puts "  Method: #{LIST_USERS.method} #{LIST_USERS.path}"
    puts "  Inputs: #{LIST_USERS.inputs.length}"
    puts "  Outputs: #{LIST_USERS.outputs.length}"
    puts "  Error responses: #{LIST_USERS.errors.length}"
    puts

    # Example 2: Endpoint metadata
    puts '2. Endpoint metadata:'
    puts "  Summary: #{GET_USER.metadata[:summary]}"
    puts "  Description: #{GET_USER.metadata[:description]}"
    puts

    # Example 3: Built-in validation
    puts '3. Endpoint validation:'
    CREATE_USER.validate!
    puts '  CREATE_USER passed built-in validation ✓'

    # Example 4: All endpoints summary
    puts
    puts '4. All endpoints:'
    [LIST_USERS, GET_USER, CREATE_USER, UPDATE_USER, DELETE_USER, LOGIN_USER].each do |ep|
      puts "  #{ep.method.to_s.ljust(6).upcase} #{ep.path}"
    end
    puts

    puts '=== Demo Complete ==='
  end
end

# Run the demo if this file is executed directly
UserAPI.demo if __FILE__ == $PROGRAM_NAME
