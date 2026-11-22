# frozen_string_literal: true

require 'ostruct'

module RapiTapir
  module Types
    # Auto-derivation module for creating RapiTapir type schemas from various sources
    #
    # This module provides automatic type inference and schema generation from:
    # - Ruby hashes with sample values
    # - JSON Schema documents
    # - OpenStruct instances
    # - Protocol Buffer message classes
    #
    # All methods support field filtering via only/except parameters.
    # rubocop:disable-next Metrics/ModuleLength
    module AutoDerivation
      class << self
        # Derive schema from a plain Hash with sample values
        #
        # @param hash [Hash] Hash with sample values for type inference
        # @param only [Array<Symbol>] Only include these fields
        # @param except [Array<Symbol>] Exclude these fields
        # @return [RapiTapir::Types::Hash]
        def from_hash(hash, only: nil, except: nil)
          raise ArgumentError, "Expected Hash, got #{hash.class}" unless hash.is_a?(::Hash)

          schema_hash = {}
          hash.each do |field_name, value|
            # Apply field filtering
            field_sym = field_name.to_sym
            next if only && !Array(only).map(&:to_sym).include?(field_sym)
            next if except && Array(except).map(&:to_sym).include?(field_sym)

            rapitapir_type = infer_type_from_value(value)
            schema_hash[field_name.to_s] = rapitapir_type
          end

          create_hash_type(schema_hash)
        end

        # Derive schema from JSON Schema object
        #
        # @param json_schema [Hash] JSON Schema object
        # @param only [Array<Symbol>] Only include these fields
        # @param except [Array<Symbol>] Exclude these fields
        # @return [RapiTapir::Types::Hash]
        def from_json_schema(json_schema, only: nil, except: nil)
          raise ArgumentError, 'JSON Schema must be an object type' unless json_schema.is_a?(::Hash) && json_schema['type'] == 'object'

          properties = json_schema['properties'] || {}
          required_fields = Array(json_schema['required'])
          schema_hash = {}

          properties.each do |field_name, field_schema|
            field_sym = field_name.to_sym
            next if only && !Array(only).map(&:to_sym).include?(field_sym)
            next if except && Array(except).map(&:to_sym).include?(field_sym)

            required = required_fields.include?(field_name)
            rapitapir_type = convert_json_schema_type(field_schema, required: required)
            schema_hash[field_name] = rapitapir_type
          end

          RapiTapir::Types.hash(schema_hash)
        end

        # Derive schema from OpenStruct instance
        #
        # @param open_struct [OpenStruct] OpenStruct with populated fields
        # @param only [Array<Symbol>] Only include these fields
        # @param except [Array<Symbol>] Exclude these fields
        # @return [RapiTapir::Types::Hash]
        # rubocop:disable-next Style/OpenStructUse
        def from_open_struct(open_struct, only: nil, except: nil)
          raise ArgumentError, "Expected OpenStruct, got #{open_struct.class}" unless open_struct.is_a?(OpenStruct)

          schema_hash = {}
          open_struct.to_h.each do |field_name, value|
            field_sym = field_name.to_sym
            next if only && !Array(only).map(&:to_sym).include?(field_sym)
            next if except && Array(except).map(&:to_sym).include?(field_sym)

            rapitapir_type = infer_type_from_value(value)
            schema_hash[field_name.to_s] = rapitapir_type
          end

          create_hash_type(schema_hash)
        end

        # Derive schema from Protobuf message class
        #
        # @param proto_class [Class] Protobuf message class
        # @param only [Array<Symbol>] Only include these fields
        # @param except [Array<Symbol>] Exclude these fields
        # @return [RapiTapir::Types::Hash]
        def from_protobuf(proto_class, only: nil, except: nil)
          raise ArgumentError, 'Protobuf not available or invalid protobuf class' unless defined?(Google::Protobuf) && proto_class.respond_to?(:descriptor)

          schema_hash = {}
          proto_class.descriptor.each do |field_descriptor|
            field_name = field_descriptor.name
            field_sym = field_name.to_sym

            next if only && !Array(only).map(&:to_sym).include?(field_sym)
            next if except && Array(except).map(&:to_sym).include?(field_sym)

            rapitapir_type = convert_protobuf_type(field_descriptor)
            schema_hash[field_name] = rapitapir_type
          end

          create_hash_type(schema_hash)
        end

        private

        # Convert JSON Schema field type to RapiTapir type
        def convert_json_schema_type(field_schema, required: true)
          base_type = case field_schema['type']
                      when 'string'
                        case field_schema['format']
                        when 'email'
                          create_email_type
                        when 'uuid'
                          create_uuid_type
                        when 'date'
                          create_date_type
                        when 'date-time'
                          create_datetime_type
                        else
                          create_string_type
                        end
                      when 'integer'
                        create_integer_type
                      when 'number'
                        create_float_type
                      when 'boolean'
                        create_boolean_type
                      when 'array'
                        item_type = if field_schema['items']
                                      convert_json_schema_type(field_schema['items'], required: true)
                                    else
                                      create_string_type
                                    end
                        create_array_type(item_type)
                      when 'object'
                        create_hash_type({})
                      else
                        create_string_type
                      end

          required ? base_type : create_optional_type(base_type)
        end

        # Convert protobuf field descriptor to RapiTapir type
        def convert_protobuf_type(field_descriptor)
          base_type = case field_descriptor.type
                      when :TYPE_INT32, :TYPE_INT64, :TYPE_UINT32, :TYPE_UINT64
                        create_integer_type
                      when :TYPE_FLOAT, :TYPE_DOUBLE
                        create_float_type
                      when :TYPE_BOOL
                        create_boolean_type
                      when :TYPE_MESSAGE
                        create_hash_type({})
                      else
                        # :TYPE_STRING, :TYPE_BYTES, :TYPE_ENUM, and others default to string
                        create_string_type
                      end

          if field_descriptor.label == :LABEL_REPEATED
            create_array_type(base_type)
          else
            base_type
          end
        end

        # Infer RapiTapir type from Ruby value
        def infer_type_from_value(value)
          case value
          when ::Integer
            create_integer_type
          when ::Float
            create_float_type
          when TrueClass, FalseClass
            create_boolean_type
          when ::Date
            create_date_type
          when ::Time, ::DateTime
            create_datetime_type
          when ::Array
            item_type = value.empty? ? create_string_type : infer_type_from_value(value.first)
            create_array_type(item_type)
          when ::Hash
            create_hash_type({})
          else
            # ::String, nil, and other unknown types default to string
            create_string_type
          end
        end

        # Helper methods to create types without using convenience methods
        def create_string_type
          RapiTapir::Types::String.new
        end

        def create_integer_type
          RapiTapir::Types::Integer.new
        end

        def create_float_type
          RapiTapir::Types::Float.new
        end

        def create_boolean_type
          RapiTapir::Types::Boolean.new
        end

        def create_date_type
          RapiTapir::Types::Date.new
        end

        def create_datetime_type
          RapiTapir::Types::DateTime.new
        end

        def create_email_type
          RapiTapir::Types::Email.new
        end

        def create_uuid_type
          RapiTapir::Types::UUID.new
        end

        def create_array_type(item_type)
          RapiTapir::Types::Array.new(item_type)
        end

        def create_hash_type(field_types)
          RapiTapir::Types::Hash.new(field_types)
        end

        def create_optional_type(base_type)
          RapiTapir::Types::Optional.new(base_type)
        end
      end
    end
  end
end
