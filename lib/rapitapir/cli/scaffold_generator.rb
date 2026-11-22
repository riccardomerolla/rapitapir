# frozen_string_literal: true

require 'json'
require 'fileutils'

module RapiTapir
  module CLI
    # ScaffoldGenerator builds a SinatraRapiTapir + ActiveRecord (SQLite) app
    # from an OpenAPI/Swagger JSON file.
    class ScaffoldGenerator
      attr_reader :openapi_path, :output_dir, :config

      def initialize(openapi_path:, output_dir:, config: {})
        @openapi_path = openapi_path
        @output_dir = output_dir
        @config = config
      end

      def generate!
        spec = JSON.parse(File.read(openapi_path))
        FileUtils.mkdir_p(output_dir)
        create_gemfile
        create_rakefile
        create_config_ru
        create_db_config
        create_app_structure
        create_models(spec)
        create_migrations(spec)
        create_api_app(spec)
        create_readme(spec)
      end

      private

      def create_gemfile
        content = <<~RUBY
              source 'https://rubygems.org'

              ruby '>= 3.2.0'

              gem 'sinatra'
              gem 'activerecord', require: 'active_record'
              gem 'sinatra-activerecord'
              gem 'sqlite3'
              gem 'rackup'
              gem 'rake'

              # API layer
          # If you're using this scaffold from inside the rapitapir repo, this local path works.
          # Otherwise, replace with: gem 'rapitapir', '~> #{RapiTapir::VERSION}'
          gem 'rapitapir', path: File.expand_path('../../..', __dir__)

              group :development, :test do
                gem 'rspec'
                gem 'rack-test'
                gem 'dotenv'
                gem 'pry'
              end
        RUBY
        write_file('Gemfile', content)
      end

      def create_rakefile
        content = <<~RUBY
          # frozen_string_literal: true

          ENV['RACK_ENV'] ||= 'development'

          require 'dotenv/load'
          require_relative 'app/api/app'
          require 'sinatra/activerecord/rake'
        RUBY
        write_file('Rakefile', content)
      end

      def create_config_ru
        content = <<~RUBY
          # frozen_string_literal: true

          $LOAD_PATH.unshift File.expand_path('app', __dir__)

          require 'bundler/setup'
          require 'rapitapir'
          require 'api/app'

          run API::App
        RUBY
        write_file('config.ru', content)
      end

      def create_db_config
        FileUtils.mkdir_p(File.join(output_dir, 'config'))
        content = <<~YAML
          development:
            adapter: sqlite3
            database: db/development.sqlite3

          test:
            adapter: sqlite3
            database: db/test.sqlite3

          production:
            adapter: sqlite3
            database: db/production.sqlite3
        YAML
        write_file('config/database.yml', content)
      end

      def create_app_structure
        %w[app app/models app/api db db/migrate spec].each do |dir|
          FileUtils.mkdir_p(File.join(output_dir, dir))
        end
      end

      def create_models(spec)
        # Minimal placeholder: one model per top-level tag (if present)
        tags = collect_tags(spec)
        tags.each do |tag|
          class_name = classify(singularize(tag))
          content = <<~RUBY
            # frozen_string_literal: true

            module Models
              class #{class_name} < ActiveRecord::Base
              end
            end
          RUBY
          write_file("app/models/#{underscore(class_name)}.rb", content)
        end
      end

      def create_migrations(spec)
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        tags = collect_tags(spec)
        tags.each_with_index do |tag, idx|
          t = (timestamp.to_i + idx).to_s
          table = pluralize(underscore(classify(tag)))
          content = <<~RUBY
            # frozen_string_literal: true

            class Create#{classify(table)} < ActiveRecord::Migration[7.1]
              def change
                create_table :#{table} do |t|
                  t.string :name
                  t.timestamps
                end
              end
            end
          RUBY
          write_file("db/migrate/#{t}_create_#{table}.rb", content)
        end
      end

      def create_api_app(spec)
        content = <<~RUBY
          # frozen_string_literal: true

          require 'sinatra/base'
          require 'sinatra/activerecord'
          require 'json'
          require 'rapitapir'
          require 'rapitapir/sinatra_rapitapir'
          require_relative '../models_loader'

          module API
            class App < RapiTapir::SinatraRapiTapir
              register Sinatra::ActiveRecordExtension
              set :database_file, File.expand_path('../../config/database.yml', __dir__)

              rapitapir do
                info(title: #{spec.dig('info', 'title').inspect}, version: #{spec.dig('info', 'version').inspect})
                development_defaults!
              end

              helpers do
                def json(obj)
                  content_type :json
                  JSON.dump(obj)
                end
              end

              # Basic health
              get '/health' do
                json(ok: true)
              end

              # Generated endpoints (scaffold level)
              #{generate_endpoints_block(spec)}
            end
          end
        RUBY
        # Also add a models_loader to require all models
        models_loader = <<~RUBY
          # frozen_string_literal: true

          Dir[File.expand_path('models/**/*.rb', __dir__)].sort.each { |f| require f }
        RUBY
        write_file('app/api/app.rb', content)
        write_file('app/models_loader.rb', models_loader)
      end

      def create_readme(spec)
        content = <<~MD
          # #{spec.dig('info', 'title') || 'RapiTapir Sinatra App'}

          Generated by RapiTapir scaffold from OpenAPI spec.

          ## Run
          ```bash
          bundle install
          bundle exec rake db:create db:migrate
          bundle exec rackup
          ```
        MD
        write_file('README.md', content)
      end

      # --- Helpers ---

      def generate_endpoints_block(spec)
        paths = spec['paths'] || {}
        blocks = []

        paths.each do |raw_path, path_item|
          next unless path_item.is_a?(Hash)

          path = to_sinatra_path(raw_path)
          operation_methods(path_item).each do |http|
            operation = path_item[http]
            blocks << endpoint_block(http, path, operation, path_item, spec)
          end
        end

        blocks.compact.join("\n\n              ")
      end

      # rubocop:disable-next Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def endpoint_block(http, path, operation, path_item, spec)
        method = http.to_s.downcase
        return nil unless %w[get post put patch delete].include?(method)

        tag = (operation.is_a?(Hash) ? operation['tags']&.first : nil) || path.split('/')[1] || 'resource'
        model = classify(tag)
        table = pluralize(underscore(model))
        model_class = "Models::#{classify(singularize(table))}"

        summary = operation.is_a?(Hash) ? (operation['summary'] || "#{method.upcase} #{path}") : "#{method.upcase} #{path}"
        description = operation.is_a?(Hash) ? operation['description'] : nil
        op_tags = operation.is_a?(Hash) ? Array(operation['tags']).compact : []

        dsl = []
        dsl << "  RapiTapir.#{method}('#{path}')"

        # Parameters (path-level + operation-level)
        params = merge_parameters(path_item, operation)
        path_param_names = extract_path_params(path)
        path_params = []
        params.each do |param|
          next unless param.is_a?(Hash)

          location = param['in']
          name = param['name']
          schema = param['schema'] || {}
          type_code = schema_to_t(schema, spec)
          # Fallback for non-body params with missing schema
          type_code = 'T.string' if (schema.nil? || !schema.is_a?(Hash) || !schema['type']) && location != 'body'
          type_code = "T.optional(#{type_code})" unless param['required']
          desc_opt = param['description'] ? ", description: #{param['description'].inspect}" : ''

          case location
          when 'path'
            if path_param_names.include?(name.to_s)
              path_params << name.to_s
              dsl << "    .path_param(:#{name}, #{type_code}#{desc_opt})"
            end
          when 'query'
            dsl << "    .query(:#{safe_symbol(name)}, #{type_code}#{desc_opt})"
          when 'header'
            # Headers keep original case/dashes as string name
            header_name = name.to_s
            dsl << "    .header(#{header_name.inspect}, #{type_code}#{desc_opt})"
          end
        end

        # Ensure any path params present in the URL but missing from parameters are covered
        (path_param_names - path_params).each do |p|
          dsl << "    .path_param(:#{p}, T.string)"
        end

        # Security headers from components/security + operation/global security
        applied_security(operation, spec).each do |scheme_name|
          scheme = spec.dig('components', 'securitySchemes', scheme_name)
          next unless scheme.is_a?(Hash)

          next unless scheme['type'] == 'apiKey' && scheme['in'] == 'header'

          header_name = scheme['name'] || scheme_name
          desc = scheme['description'] ? ", description: #{scheme['description'].inspect}" : ''
          dsl << "    .header(#{header_name.inspect}, T.string#{desc})"
        end

        # Request body
        if (schema = request_body_schema(operation, spec))
          dsl << "    .json_body(#{schema_to_t(schema, spec)})"
        end

        # Output (map first 2xx response schema)
        success_code = operation.is_a?(Hash) ? (first_success_code(operation) || 200) : 200
        if success_code == 204
          dsl << '    .no_content'
        else
          resp_schema = response_schema_for_code(operation, success_code, spec)
          type_expr = resp_schema ? schema_to_t(resp_schema, spec) : 'T.hash({})'
          dsl << if success_code == 201
                   "    .created(#{type_expr})"
                 else
                   "    .ok(#{type_expr})"
                 end
        end

        dsl << "    .summary(#{summary.inspect})"
        dsl << "    .description(#{description.inspect})" if description && !description.strip.empty?
        dsl << "    .tags(#{op_tags.map(&:inspect).join(', ')})" if op_tags.any?
        dsl << '.build'

        handler = default_handler(method, table, model_class, path_param_names, success_code)

        <<~RUBY
          endpoint(
            #{dsl.join("\n            ")}
          ) do
            #{handler}
          end
        RUBY
      end

      # Combine path-level and operation-level parameters. Later duplicates override earlier.
      def merge_parameters(path_item, operation)
        seen = {}
        [path_item['parameters'], operation.is_a?(Hash) ? operation['parameters'] : nil].compact.each do |arr|
          next unless arr.is_a?(Array)

          arr.each do |param|
            next unless param.is_a?(Hash)

            key = [param['in'], param['name']].join(':')
            seen[key] = param
          end
        end
        # Maintain stable order grouped by location
        seen.values
      end

      def request_body_schema(operation, spec)
        return nil unless operation.is_a?(Hash)

        content = operation.dig('requestBody', 'content')
        return nil unless content.is_a?(Hash)

        # Prefer JSON
        json = content['application/json'] || content.values.first
        return nil unless json.is_a?(Hash)

        schema = json['schema']
        resolved = resolve_schema(schema, spec)
        # Attach original component name to metadata for OpenAPI generator pass-through
        if schema.is_a?(Hash) && schema['$ref']
          name = schema['$ref'].split('/').last
          return resolved.merge('__component_name__' => name) if resolved.is_a?(Hash)
        end
        resolved
      end

      def response_schema_for_code(operation, code, spec)
        return nil unless operation.is_a?(Hash)

        resp = (operation['responses'] || {})[code.to_s]
        return nil unless resp.is_a?(Hash)

        content = resp['content']
        return nil unless content.is_a?(Hash)

        json = content['application/json'] || content.values.first
        return nil unless json.is_a?(Hash)

        schema = json['schema']
        resolved = resolve_schema(schema, spec)
        if schema.is_a?(Hash) && schema['$ref']
          name = schema['$ref'].split('/').last
          return resolved.merge('__component_name__' => name) if resolved.is_a?(Hash)
        end
        resolved
      end

      # --- OpenAPI schema -> RapiTapir::Types DSL (as string) ---
      # rubocop:disable-next Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def schema_to_t(schema, spec)
        schema = resolve_schema(schema, spec) || {}
        return 'T.hash({})' unless schema.is_a?(Hash)

        component_name = schema['__component_name__']

        # Nullable -> make optional
        nullable = schema['nullable']

        type_expr = case schema['type']
                    when 'string'
                      fmt = (schema['format'] || '').downcase
                      base = case fmt
                             when 'date-time' then 'T.datetime'
                             when 'date' then 'T.date'
                             when 'email' then 'T.email'
                             when 'uuid', 'guid' then 'T.uuid'
                             else 'T.string'
                             end
                      constraints = []
                      constraints << "min_length: #{schema['minLength']}" if schema.key?('minLength')
                      constraints << "max_length: #{schema['maxLength']}" if schema.key?('maxLength')
                      constraints.empty? ? base : "#{base}(#{constraints.join(', ')})"
                    when 'integer'
                      constraints = []
                      constraints << "minimum: #{schema['minimum']}" if schema.key?('minimum')
                      constraints << "maximum: #{schema['maximum']}" if schema.key?('maximum')
                      constraints.empty? ? 'T.integer' : "T.integer(#{constraints.join(', ')})"
                    when 'number'
                      constraints = []
                      constraints << "minimum: #{schema['minimum']}" if schema.key?('minimum')
                      constraints << "maximum: #{schema['maximum']}" if schema.key?('maximum')
                      constraints.empty? ? 'T.float' : "T.float(#{constraints.join(', ')})"
                    when 'boolean'
                      'T.boolean'
                    when 'array'
                      items = schema_to_t(schema['items'] || {}, spec)
                      "T.array(#{items})"
                    when 'object', nil
                      # If properties exist -> T.hash, otherwise generic object
                      props = schema['properties'] || {}
                      required = Array(schema['required'])
                      if props.any?
                        inner = props.map do |k, v|
                          t = schema_to_t(v, spec)
                          t = "T.optional(#{t})" unless required.include?(k.to_s)
                          "\"#{k}\" => #{t}"
                        end.join(', ')
                        "T.hash({ #{inner} })"
                      else
                        'T.hash({})'
                      end
                    else
                      'T.hash({})'
                    end

        # Attach original component name if present
        type_expr = "#{type_expr}.with_metadata(component_name: #{component_name.inspect})" if component_name

        nullable ? "T.optional(#{type_expr})" : type_expr
      end

      def resolve_schema(schema, spec)
        return nil unless schema

        if schema.is_a?(Hash) && schema['$ref']
          obj = resolve_ref(schema['$ref'], spec)
          if obj
            name = schema['$ref'].split('/').last
            dup = obj.dup
            dup['__component_name__'] = name
            dup
          else
            schema
          end
        else
          schema
        end
      end

      def resolve_ref(ref, spec)
        return nil unless ref.is_a?(String)

        return unless ref.start_with?('#/components/schemas/')

        name = ref.split('/').last
        (spec.dig('components', 'schemas', name) || {}).dup
      end

      # Effective security requirements: operation-level overrides global when present
      def applied_security(operation, spec)
        names = []
        security = operation.is_a?(Hash) && operation['security'] ? operation['security'] : spec['security']
        Array(security).each do |sec_req|
          next unless sec_req.is_a?(Hash)

          names.concat(sec_req.keys)
        end
        names.uniq
      end

      def default_handler(method, _table, model_class, path_params, success_code)
        case method
        when 'get'
          if path_params.any?
            pk = path_params.first
            <<~RUBY.strip
              rec = #{model_class}.find_by(id: params[:#{pk}])
              halt 404 unless rec
              rec.attributes
            RUBY
          else
            "#{model_class}.limit(25).all.map(&:attributes)"
          end
        when 'post'
          <<~RUBY.strip
            payload = JSON.parse(request.body.read) rescue {}
            model = #{model_class}.create(payload)
            model.attributes
          RUBY
        when 'put', 'patch'
          if path_params.any?
            pk = path_params.first
            <<~RUBY.strip
              payload = JSON.parse(request.body.read) rescue {}
              model = #{model_class}.find_by(id: params[:#{pk}])
              halt 404 unless model
              model.update(payload)
              model.attributes
            RUBY
          else
            <<~RUBY.strip
              payload = JSON.parse(request.body.read) rescue {}
              model = #{model_class}.first
              halt 404 unless model
              model.update(payload)
              model.attributes
            RUBY
          end
        when 'delete'
          if path_params.any?
            pk = path_params.first
            <<~RUBY.strip
              model = #{model_class}.find_by(id: params[:#{pk}])
              halt 404 unless model
              model.destroy
              #{success_code == 204 ? "''" : '{}'}
            RUBY
          else
            <<~RUBY.strip
              model = #{model_class}.first
              halt 404 unless model
              model.destroy
              #{success_code == 204 ? "''" : '{}'}
            RUBY
          end
        else
          '{}'
        end
      end

      def first_success_code(operation)
        (operation['responses'] || {}).keys.map(&:to_i).grep(200..299).first
      end

      def to_sinatra_path(openapi_path)
        openapi_path.gsub('{', ':').gsub('}', '')
      end

      def from_openapi_path(sinatra_path)
        sinatra_path.gsub(/:([a-zA-Z_]\w*)/, '{\1}')
      end

      def extract_path_params(path)
        path.scan(/:([a-zA-Z_]\w*)/).flatten
      end

      def collect_tags(spec)
        tags = []
        (spec['paths'] || {}).each_value do |path_item|
          next unless path_item.is_a?(Hash)

          operation_methods(path_item).each do |m|
            op = path_item[m]
            tags.concat(Array(op['tags'])) if op.is_a?(Hash) && op['tags']
          end
        end
        tags = tags.uniq
        return tags unless tags.empty?

        # Fallback: derive from first path segment
        (spec['paths'] || {}).keys.map { |p| p.to_s.split('/')[1] }.compact.uniq
      end

      def operation_methods(path_item)
        %w[get post put patch delete].select { |m| path_item.key?(m) }
      end

      # String helpers (lightweight, no ActiveSupport)
      def classify(name)
        name.to_s.split(/[_\-\s]/).map { |p| p[0].upcase + p[1..].to_s }.join
      end

      def underscore(name)
        name.to_s
            .gsub('::', '/')
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
            .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
            .tr('-', '_')
            .downcase
      end

      def pluralize(word)
        return word if word.end_with?('s')
        return "#{word[0..-2]}ies" if word.end_with?('y')

        "#{word}s"
      end

      def singularize(word)
        return word[0..-2] if word.end_with?('s')
        return "#{word[0..-4]}y" if word.end_with?('ies')

        word
      end

      def write_file(rel_path, content)
        abs = File.join(output_dir, rel_path)
        FileUtils.mkdir_p(File.dirname(abs))
        File.write(abs, content)
      end

      def safe_symbol(name)
        n = name.to_s.strip
        n = n.gsub('-', '_')
        n = n.gsub(/[^a-zA-Z0-9_]/, '_')
        # Allow CamelCase/camelCase symbols as-is, just ensure starts with letter
        n = "param_#{n}" unless n =~ /[A-Za-z_]/
        n
      end
    end
  end
end
