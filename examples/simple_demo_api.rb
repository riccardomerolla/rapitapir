# frozen_string_literal: true

require_relative '../lib/rapitapir'

USER_LIST_TYPE = RapiTapir::Types.array(
  RapiTapir::Types.hash({
    'id' => RapiTapir::Types.integer,
    'name' => RapiTapir::Types.string,
    'email' => RapiTapir::Types.string
  })
)

USER_TYPE = RapiTapir::Types.hash({
  'id' => RapiTapir::Types.integer,
  'name' => RapiTapir::Types.string,
  'email' => RapiTapir::Types.string
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

# Simple API endpoints for demonstration
RapiTapir.get('/users')
         .ok(USER_LIST_TYPE)
         .summary('List all users')
         .description('Retrieve a paginated list of all users in the system')
         .build

RapiTapir.post('/users')
         .json_body(CREATE_USER_TYPE)
         .created(USER_TYPE)
         .bad_request(VALIDATION_ERROR_TYPE)
         .unprocessable_entity(ERROR_TYPE)
         .summary('Create new user')
         .description('Create a new user account with the provided information')
         .build

puts "✅ Defined #{RapiTapir.endpoints.size} endpoints"
