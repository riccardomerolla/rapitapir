# frozen_string_literal: true

require_relative '../lib/rapitapir'

# Type definitions
USER_TYPE = RapiTapir::Types.hash({
  'id' => RapiTapir::Types.integer,
  'name' => RapiTapir::Types.string,
  'email' => RapiTapir::Types.string
})

USER_FULL_TYPE = RapiTapir::Types.hash({
  'id' => RapiTapir::Types.integer,
  'name' => RapiTapir::Types.string,
  'email' => RapiTapir::Types.string,
  'created_at' => RapiTapir::Types.string
})

CREATE_USER_TYPE = RapiTapir::Types.hash({
  'name' => RapiTapir::Types.string,
  'email' => RapiTapir::Types.string,
  'password' => RapiTapir::Types.string
})

ERROR_TYPE = RapiTapir::Types.hash({
  'error' => RapiTapir::Types.string,
  'message' => RapiTapir::Types.string
})

VALIDATION_ERROR_TYPE = RapiTapir::Types.hash({
  'error' => RapiTapir::Types.string,
  'validation_errors' => RapiTapir::Types.array(RapiTapir::Types.string)
})

# Sample API endpoints for demonstration
RapiTapir.get('/users')
         .ok(RapiTapir::Types.array(USER_TYPE))
         .summary('List all users')
         .description('Retrieve a paginated list of all users in the system')
         .build

RapiTapir.get('/users/:id')
         .path_param(:id, RapiTapir::Types.integer)
         .ok(USER_FULL_TYPE)
         .not_found(ERROR_TYPE)
         .summary('Get user by ID')
         .description('Retrieve detailed information about a specific user')
         .build

RapiTapir.post('/users')
         .json_body(CREATE_USER_TYPE)
         .created(USER_TYPE)
         .bad_request(VALIDATION_ERROR_TYPE)
         .unprocessable_entity(ERROR_TYPE)
         .summary('Create new user')
         .description('Create a new user account with the provided information')
         .build

RapiTapir.put('/users/:id')
         .path_param(:id, RapiTapir::Types.integer)
         .json_body(RapiTapir::Types.hash({
                     'name' => RapiTapir::Types.string,
                     'email' => RapiTapir::Types.string
                   }))
         .ok(USER_FULL_TYPE)
         .not_found(ERROR_TYPE)
         .bad_request(VALIDATION_ERROR_TYPE)
         .summary('Update user')
         .description('Update an existing user with new information')
         .build

RapiTapir.delete('/users/:id')
         .path_param(:id, RapiTapir::Types.integer)
         .no_content
         .not_found(ERROR_TYPE)
         .summary('Delete user')
         .description('Permanently delete a user account')
         .build

puts "✅ Defined #{RapiTapir.endpoints.size} endpoints"
