# frozen_string_literal: true

require_relative '../../lib/rapitapir'

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

# Define endpoints for CLI usage
user_api_endpoints = [
  # Get all users
  RapiTapir.get('/users')
           .ok(RapiTapir::Types.array(USER_TYPE))
           .summary('Get all users')
           .description('Retrieve a list of all users')
           .build,

  # Get user by ID
  RapiTapir.get('/users/:id')
           .path_param(:id, RapiTapir::Types.integer)
           .ok(USER_FULL_TYPE)
           .not_found(ERROR_TYPE)
           .summary('Get user by ID')
           .description('Retrieve a specific user by their ID')
           .build,

  # Create a new user
  RapiTapir.post('/users')
           .json_body(CREATE_USER_TYPE)
           .created(USER_TYPE)
           .bad_request(VALIDATION_ERROR_TYPE)
           .summary('Create a new user')
           .description('Create a new user account')
           .build,

  # Update a user
  RapiTapir.put('/users/:id')
           .path_param(:id, RapiTapir::Types.integer)
           .json_body(RapiTapir::Types.hash({
                       'name' => RapiTapir::Types.string,
                       'email' => RapiTapir::Types.string
                     }))
           .ok(USER_FULL_TYPE)
           .not_found(ERROR_TYPE)
           .bad_request(VALIDATION_ERROR_TYPE)
           .summary('Update a user')
           .description('Update an existing user')
           .build,

  # Delete a user
  RapiTapir.delete('/users/:id')
           .path_param(:id, RapiTapir::Types.integer)
           .no_content
           .not_found(ERROR_TYPE)
           .summary('Delete a user')
           .description('Permanently delete a user account')
           .build
]
