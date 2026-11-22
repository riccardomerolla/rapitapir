# frozen_string_literal: true

# This file demonstrates the auto-derivation capabilities of RapiTapir's type
# system, working well with Ruby's dynamic nature and lack of built-in type
# declarations.

require_relative '../lib/rapitapir/types'

puts '=== RapiTapir Auto-Derivation Examples ==='
puts

# 1. From Hash (most reliable for Ruby)
puts '1. From Hash (recommended for Ruby)'
hash_data = {
  name: 'John Doe',
  age: 30,
  email: 'john@example.com',
  active: true,
  score: 95.5,
  tags: ['developer', 'ruby'],
  metadata: { role: 'senior', team: 'backend' }
}

schema = RapiTapir::Types.from_hash(hash_data)
puts 'Schema from hash:'
puts schema.field_types.inspect
puts

# 2. From Hash with filtering
puts '2. From Hash with filtering'
filtered_schema = RapiTapir::Types.from_hash(hash_data, except: [:metadata])
puts "Schema with 'except' filtering:"
puts filtered_schema.field_types.inspect
puts

filtered_only = RapiTapir::Types.from_hash(hash_data, only: [:name, :email])
puts "Schema with 'only' filtering:"
puts filtered_only.field_types.inspect
puts

# 3. OpenStruct (convenient for prototyping)
puts '3. From OpenStruct'
require 'ostruct'

config = OpenStruct.new(
  host: 'localhost',
  port: 3000,
  ssl: false,
  timeout: 30.5
)

config_schema = RapiTapir::Types.from_open_struct(config)
puts 'Config schema from OpenStruct:'
puts config_schema.field_types.inspect
puts

# 4. JSON Schema (for external APIs)
puts '4. From JSON Schema'
json_schema = {
  'type' => 'object',
  'properties' => {
    'id' => { 'type' => 'integer' },
    'name' => { 'type' => 'string', 'maxLength' => 100 },
    'email' => { 'type' => 'string', 'format' => 'email' },
    'created_at' => { 'type' => 'string', 'format' => 'date-time' },
    'tags' => {
      'type' => 'array',
      'items' => { 'type' => 'string' }
    }
  },
  'required' => ['id', 'name', 'email']
}

json_derived_schema = RapiTapir::Types.from_json_schema(json_schema)
puts 'Schema from JSON Schema:'
puts json_derived_schema.field_types.inspect
puts

# 5. Protobuf (when available)
puts '5. From Protobuf (if a protobuf descriptor is available)'
begin
  require 'google/protobuf' # rubocop:disable Lint/RequireRelativeSelfPath
  puts '   google-protobuf is available — from_protobuf(Descriptor) is supported'
rescue LoadError
  puts '   google-protobuf not installed — from_protobuf is available once it is'
end
puts

puts '=== Recommendations ==='
puts '1. Use from_hash() for parsed JSON or config data'
puts '2. Use from_open_struct() for prototyping'
puts '3. Use from_json_schema() for external API integration'
puts '4. Use from_protobuf() when wrapping protobuf messages'
puts '5. Avoid deriving from empty hashes or nil values'
