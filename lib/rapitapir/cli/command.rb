# frozen_string_literal: true

require 'optparse'
require 'fileutils'
require 'json'

module RapiTapir
  module CLI
    # Command-line interface for RapiTapir operations
    # Provides commands for generating OpenAPI specs, clients, and documentation
    class Command
      attr_reader :options

      def initialize(args = ARGV)
        @args = args
        @options = {
          input: nil,
          output: nil,
          format: 'json',
          config: {}
        }
      end

      def run
        parser = create_option_parser

        begin
          parser.parse!(@args)
          command = @args.shift
          dispatch_command(command, parser)
        rescue OptionParser::InvalidOption => e
          handle_option_error(e, parser)
        rescue StandardError => e
          handle_general_error(e)
        end
      end

      def dispatch_command(command, parser)
        case command
        when 'generate'
          run_generate(@args)
        when 'export'
          run_export(@args)
        when 'serve'
          run_serve(@args)
        when 'validate'
          run_validate(@args)
        when 'ai'
          run_ai(@args)
        when 'version'
          puts "RapiTapir version #{RapiTapir::VERSION}"
        when 'help', nil
          puts parser.help
        else
          handle_unknown_command(command, parser)
        end
      end

      def handle_unknown_command(command, parser)
        puts "Unknown command: #{command}"
        puts parser.help
        exit 1
      end

      def handle_option_error(error, parser)
        puts "Error: #{error.message}"
        puts parser.help
        exit 1
      end

      def handle_general_error(error)
        puts "Error: #{error.message}"
        raise error if ENV['RSPEC_RUNNING']

        exit 1
      end

      private

      def create_option_parser
        OptionParser.new do |opts|
          setup_banner_and_commands(opts)
          setup_file_options(opts)
          setup_config_options(opts)
          setup_help_and_version_options(opts)
        end
      end

      def setup_banner_and_commands(opts)
        opts.banner = 'Usage: rapitapir [options] command [args]'
        opts.separator ''
        opts.separator 'Commands:'
        opts.separator '  generate TYPE    Generate clients or documentation'
        opts.separator '  serve           Start documentation server'
        opts.separator '  validate        Validate endpoint definitions'
        opts.separator '  version         Show version'
        opts.separator '  help            Show this help'
        opts.separator ''
        opts.separator 'Options:'
      end

      def setup_file_options(opts)
        opts.on('-i', '--input FILE', '--endpoints FILE', 'Input Ruby file with endpoint definitions') do |file|
          @options[:input] = file
        end

        opts.on('-o', '--output FILE', 'Output file path') do |file|
          @options[:output] = file
        end

        opts.on('-f', '--format FORMAT', 'Output format (json, yaml, ts, py, md, html)') do |format|
          @options[:format] = format
        end
      end

      def setup_config_options(opts)
        setup_generic_config_option(opts)
        setup_specific_config_options(opts)
      end

      def setup_generic_config_option(opts)
        opts.on('-c', '--config KEY=VALUE', 'Configuration option (can be used multiple times)') do |config|
          key, value = config.split('=', 2)
          @options[:config][key.to_sym] = value
        end
      end

      def setup_specific_config_options(opts)
        config_mappings = {
          '--base-url URL' => [:base_url, 'Base URL for the API'],
          '--client-name NAME' => [:client_name, 'Name for generated client class'],
          '--package-name NAME' => [:package_name, 'Package name for generated client'],
          '--client-version VERSION' => [:version, 'Version for generated client']
        }

        config_mappings.each do |option_spec, (config_key, description)|
          opts.on(option_spec, description) do |value|
            @options[:config][config_key] = value
          end
        end
      end

      public

      def setup_help_and_version_options(opts)
        opts.on('-v', '--version', 'Show RapiTapir version') do
          puts "RapiTapir version #{RapiTapir::VERSION}"
          exit
        end

        opts.on('-h', '--help', 'Show this help') do
          puts opts
          exit
        end
      end

      def run_generate(args)
        type = args.shift
        unless type
          puts 'Error: Generate command requires a type'
          puts 'Available types: openapi, client, docs, mcp'
          exit 1
        end

        case type
        when 'openapi'
          generate_openapi
        when 'client'
          client_type = args.shift || 'typescript'
          generate_client(client_type)
        when 'docs'
          docs_type = args.shift || 'html'
          generate_docs(docs_type)
        when 'scaffold'
          generate_scaffold(args)
        when 'mcp'
          generate_mcp
        else
          puts "Error: Unknown generation type: #{type}"
          # Keep this list stable for backward compatibility with existing tests
          puts 'Available types: openapi, client, docs, mcp'
          exit 1
        end
      end

      def run_serve(args)
        port = args.shift || '3000'

        unless @options[:input]
          puts 'Error: --endpoints option is required for serve command'
          exit 1
        end

        require_relative 'server'
        server = CLI::Server.new(endpoints_file: @options[:input], port: port.to_i, config: @options[:config] || {})
        puts "Starting documentation server on port #{port}..."
        server.start
      end

      def run_validate(_args)
        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        endpoints = load_endpoints(@options[:input])
        require_relative 'validator'
        validator = CLI::Validator.new(endpoints)

        if validator.validate
          puts '✓ All endpoints are valid'
        else
          puts '✗ Validation failed:'
          validator.errors.each { |error| puts "  - #{error}" }
          exit 1
        end
      end

      def run_export(args)
        type = args.shift
        unless type
          puts 'Error: Export command requires a type'
          puts 'Available types: mcp'
          exit 1
        end

        case type
        when 'mcp'
          export_mcp
        else
          puts "Error: Unknown export type: #{type}"
          puts 'Available types: mcp'
          exit 1
        end
      end

      def generate_openapi
        validate_openapi_options

        begin
          endpoints = load_endpoints(@options[:input])
          generator = create_openapi_generator(endpoints)
          content = generate_openapi_content(generator)
          save_openapi_output(content)
        rescue StandardError => e
          handle_openapi_error(e)
        end
      end

      def validate_openapi_options
        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        return if @options[:output]

        puts 'Error: --output is required'
        exit 1
      end

      def create_openapi_generator(endpoints)
        require_relative '../openapi/schema_generator'

        openapi_info = build_openapi_info
        openapi_servers = build_openapi_servers

        RapiTapir::OpenAPI::SchemaGenerator.new(
          endpoints: endpoints,
          info: openapi_info,
          servers: openapi_servers
        )
      end

      def build_openapi_info
        {
          title: @options[:config][:title] || 'API Documentation',
          version: @options[:config][:version] || '1.0.0',
          description: @options[:config][:description] || 'Auto-generated API documentation'
        }
      end

      def build_openapi_servers
        servers = []
        servers << { url: @options[:config][:base_url] } if @options[:config][:base_url]
        servers
      end

      def generate_openapi_content(generator)
        case @options[:format]
        when 'yaml', 'yml'
          generator.to_yaml
        else
          generator.to_json
        end
      end

      def save_openapi_output(content)
        if @options[:output]
          File.write(@options[:output], content)
          puts "OpenAPI schema saved to #{@options[:output]}"
        else
          puts content
        end
      end

      def handle_openapi_error(error)
        puts "Error generating OpenAPI schema: #{error.message}"
        puts "Backtrace: #{error.backtrace.first(5).join("\n")}"
        exit 1
      end

      def generate_client(client_type)
        validate_client_options

        endpoints = load_endpoints(@options[:input])
        generator, extension = create_client_generator(client_type, endpoints)
        content = generator.generate
        save_client_output(content, client_type, extension)
      end

      def validate_client_options
        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        return if @options[:output]

        puts 'Error: --output is required'
        exit 1
      end

      def create_client_generator(client_type, endpoints)
        case client_type
        when 'typescript', 'ts'
          generator = create_typescript_generator(endpoints)
          [generator, 'ts']
        when 'python', 'py'
          handle_python_generator_not_implemented
        else
          handle_unknown_client_type(client_type)
        end
      end

      def create_typescript_generator(endpoints)
        require_relative '../client/typescript_generator'
        RapiTapir::Client::TypescriptGenerator.new(
          endpoints: endpoints,
          config: @options[:config]
        )
      end

      def handle_python_generator_not_implemented
        puts 'Error: Python client generator not implemented yet'
        exit 1
      end

      def handle_unknown_client_type(client_type)
        puts "Error: Unknown client type: #{client_type}"
        puts 'Available types: typescript, python'
        exit 1
      end

      def save_client_output(content, client_type, extension)
        if @options[:output]
          File.write(@options[:output], content)
          puts "#{client_type.capitalize} client saved to #{@options[:output]}"
        else
          default_output = "api-client.#{extension}"
          File.write(default_output, content)
          puts "#{client_type.capitalize} client saved to #{default_output}"
        end
      end

      def generate_docs(docs_type)
        validate_docs_options

        endpoints = load_endpoints(@options[:input])
        generator, extension = create_docs_generator(docs_type, endpoints)
        content = generator.generate
        save_docs_output(content, docs_type, extension)
      end

      def validate_docs_options
        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        return if @options[:output]

        puts 'Error: --output is required'
        exit 1
      end

      def create_docs_generator(docs_type, endpoints)
        case docs_type
        when 'markdown', 'md'
          generator = create_markdown_generator(endpoints)
          [generator, 'md']
        when 'html'
          generator = create_html_generator(endpoints)
          [generator, 'html']
        else
          handle_unknown_docs_type(docs_type)
        end
      end

      def generate_scaffold(_args)
        unless @options[:input]
          puts 'Error: --input must point to an OpenAPI/Swagger JSON file'
          exit 1
        end

        output_dir = @options[:output] || 'rapitapir_sinatra_app'

        begin
          require_relative 'scaffold_generator'
          generator = RapiTapir::CLI::ScaffoldGenerator.new(
            openapi_path: @options[:input],
            output_dir: output_dir,
            config: @options[:config]
          )
          generator.generate!
          puts "Scaffold generated at #{output_dir}"
          puts "Next steps:\n  1) cd #{output_dir}\n  2) bundle install\n  3) bundle exec rake db:create db:migrate\n  4) bundle exec rackup"
        rescue StandardError => e
          puts "Error generating scaffold: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          exit 1
        end
      end

      def create_markdown_generator(endpoints)
        require_relative '../docs/markdown_generator'
        RapiTapir::Docs::MarkdownGenerator.new(
          endpoints: endpoints,
          config: @options[:config]
        )
      end

      def create_html_generator(endpoints)
        require_relative '../docs/html_generator'
        RapiTapir::Docs::HtmlGenerator.new(
          endpoints: endpoints,
          config: @options[:config]
        )
      end

      def handle_unknown_docs_type(docs_type)
        puts "Error: Unknown documentation type: #{docs_type}"
        puts 'Available types: markdown, html'
        exit 1
      end

      def save_docs_output(content, docs_type, extension)
        if @options[:output]
          File.write(@options[:output], content)
          puts "#{docs_type.capitalize} documentation saved to #{@options[:output]}"
        else
          default_output = "api-docs.#{extension}"
          File.write(default_output, content)
          puts "#{docs_type.capitalize} documentation saved to #{default_output}"
        end
      end

      def generate_mcp
        validate_mcp_options

        endpoints = load_endpoints(@options[:input])
        require_relative '../ai/mcp'
        exporter = RapiTapir::AI::MCP::Exporter.new(endpoints)
        content = JSON.pretty_generate(exporter.as_mcp_context)
        save_mcp_output(content)
      end

      def export_mcp
        generate_mcp
      end

      def validate_mcp_options
        return if @options[:input]

        puts 'Error: --endpoints is required'
        exit 1
      end

      def save_mcp_output(content)
        output_file = @options[:output] || 'mcp-context.json'
        File.write(output_file, content)
        puts "MCP context exported to #{output_file}"
      end

      def load_endpoints(file_path)
        raise "Input file not found: #{file_path}" unless File.exist?(file_path)

        prepare_loading_environment(file_path) do
          content = File.read(file_path)
          load_endpoints_from_content(content, file_path) || load_endpoints_fallback(file_path)
        end
      end

      def prepare_loading_environment(file_path)
        # Store original state
        original_endpoints = RapiTapir.instance_variable_get(:@endpoints) || []
        original_load_path = $LOAD_PATH.dup

        # Add the file's directory to load path for relative requires
        file_dir = File.dirname(File.expand_path(file_path))
        $LOAD_PATH.unshift(file_dir) unless $LOAD_PATH.include?(file_dir)

        RapiTapir.instance_variable_set(:@endpoints, [])

        begin
          yield
        rescue SyntaxError => e
          raise "Syntax error in #{file_path}: #{e.message}"
        ensure
          RapiTapir.instance_variable_set(:@endpoints, original_endpoints)
          $LOAD_PATH.replace(original_load_path)
        end
      end

      def load_endpoints_from_content(content, file_path)
        return nil unless content.match?(/(\w+_api|\w+_endpoints|\wendpoints\w*)\s*=\s*\[/)

        file_dir = File.dirname(File.expand_path(file_path))
        Dir.chdir(file_dir) do
          # Execute the file content using load instead of eval for safety
          # rubocop:disable-next Security/Eval
          eval(content, TOPLEVEL_BINDING, file_path)
        end

        find_endpoints_in_variables(content)
      end

      def find_endpoints_in_variables(content)
        # Try instance variables
        endpoints = find_endpoints_in_instance_variables
        return endpoints if endpoints

        # Try global variables
        endpoints = find_endpoints_in_global_variables
        return endpoints if endpoints

        # Try content-matched variables
        find_endpoints_in_content_variables(content)
      end

      def find_endpoints_in_instance_variables
        main_obj = TOPLEVEL_BINDING.eval('self')
        endpoints_var = main_obj.instance_variables.find do |var|
          var.to_s.include?('api') || var.to_s.include?('endpoint')
        end

        return nil unless endpoints_var

        endpoints = main_obj.instance_variable_get(endpoints_var)
        normalize_endpoints_array(endpoints)
      end

      def find_endpoints_in_global_variables
        global_endpoints_var = global_variables.find do |var|
          var.to_s.include?('api') || var.to_s.include?('endpoint')
        end

        return nil unless global_endpoints_var

        # rubocop:disable-next Security/Eval
        endpoints = eval(global_endpoints_var.to_s)
        normalize_endpoints_array(endpoints)
      end

      def find_endpoints_in_content_variables(content)
        var_match = content.match(/(\w+_api|\w+_endpoints|\wendpoints\w*)\s*=/)
        return nil unless var_match

        var_name = var_match[1]
        begin
          # rubocop:disable Security/Eval
          endpoints = eval(var_name, TOPLEVEL_BINDING)
          # rubocop:enable Security/Eval
          normalize_endpoints_array(endpoints)
        rescue NameError
          nil
        end
      end

      def normalize_endpoints_array(endpoints)
        return nil unless endpoints

        endpoints = [endpoints] unless endpoints.is_a?(Array)
        endpoints.flatten.compact
      end

      def load_endpoints_fallback(file_path)
        # Fallback: try loading the file normally
        load File.expand_path(file_path)
        endpoints = RapiTapir.instance_variable_get(:@endpoints) || []

        if endpoints.empty?
          error_msg = "No endpoints found in #{file_path}. " \
                      'Make sure the file defines endpoints in a variable ' \
                      "containing 'api' or 'endpoints' in its name."
          raise error_msg
        end

        endpoints
      end

      def run_ai(args)
        subcommand = args.shift

        case subcommand
        when 'rag'
          run_ai_rag(args)
        when 'query'
          run_ai_query(args)
        when 'llm'
          run_ai_llm(args)
        when 'help', nil
          puts ai_help
        else
          puts "Unknown AI subcommand: #{subcommand}"
          puts ai_help
          exit 1
        end
      end

      def run_ai_rag(args)
        command = args.shift

        case command
        when 'test'
          run_rag_test(args)
        when 'setup'
          run_rag_setup(args)
        else
          puts 'RAG subcommands: test, setup'
          exit 1
        end
      end

      def run_rag_test(args)
        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        endpoints = load_endpoints(@options[:input])

        # Find RAG-enabled endpoints
        rag_endpoints = endpoints.select(&:rag_inference?)

        if rag_endpoints.empty?
          puts "No RAG-enabled endpoints found in #{@options[:input]}"
          puts 'Add .rag_inference to your endpoints to enable RAG capabilities'
          exit 1
        end

        require_relative '../ai/rag'

        puts 'Testing RAG functionality...'
        puts "Found #{rag_endpoints.size} RAG-enabled endpoint(s):"

        rag_endpoints.each do |endpoint|
          puts "  #{endpoint.method} #{endpoint.path}"
          config = endpoint.rag_config

          # Create pipeline and test
          pipeline = RapiTapir::AI::RAG::Pipeline.new(
            llm: config[:llm] || :openai,
            retrieval: config[:retrieval] || :memory,
            config: config[:config] || {}
          )

          test_query = args.first || 'What can this API do?'
          result = pipeline.process(test_query)

          puts "    Query: #{test_query}"
          puts "    Answer: #{result[:answer][0..100]}#{'...' if result[:answer].length > 100}"
          puts "    Sources: #{result[:sources].size} document(s)"
          puts
        end
      end

      def run_rag_setup(_args)
        puts 'Setting up RAG configuration...'

        config_template = {
          rag: {
            llm: {
              provider: 'openai',
              api_key: 'your-openai-api-key'
            },
            retrieval: {
              backend: 'memory',
              documents_path: './docs/**/*.md'
            }
          }
        }

        config_file = 'rapitapir_ai.json'

        if File.exist?(config_file)
          puts "Configuration file #{config_file} already exists"
          exit 1
        end

        File.write(config_file, JSON.pretty_generate(config_template))
        puts "Created #{config_file}"
        puts 'Please update the configuration with your API keys and document paths'
      end

      def run_ai_query(args)
        query = args.join(' ')

        if query.empty?
          puts 'Usage: rapitapir ai query <your question>'
          exit 1
        end

        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        endpoints = load_endpoints(@options[:input])

        # Export MCP context for the query
        require_relative '../ai/mcp'
        exporter = RapiTapir::AI::MCP::Exporter.new(endpoints)
        context = exporter.as_mcp_context

        puts 'API Context for AI Agents:'
        puts '========================='
        puts
        puts "Query: #{query}"
        puts
        puts 'Available Endpoints:'
        if context && context[:endpoints]
          context[:endpoints].each do |ep|
            puts "  #{ep[:method]} #{ep[:path]} - #{ep[:summary]}"
          end
        else
          puts '  No endpoints found'
        end
        puts
        puts 'This context can be used by AI agents to understand your API structure.'
      end

      def run_ai_llm(args)
        command = args.shift

        case command
        when 'generate'
          run_llm_generate(args)
        when 'export'
          run_llm_export(args)
        when 'test'
          run_llm_test(args)
        else
          puts 'LLM subcommands: generate, export, test'
          exit 1
        end
      end

      def run_llm_generate(_args)
        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        endpoints = load_endpoints(@options[:input])

        # Find LLM instruction-enabled endpoints
        llm_endpoints = endpoints.select(&:llm_instruction?)

        if llm_endpoints.empty?
          puts "No LLM instruction-enabled endpoints found in #{@options[:input]}"
          puts 'Add .llm_instruction(purpose: :validation) to your endpoints to enable LLM instruction generation'
          exit 1
        end

        require_relative '../ai/llm_instruction'

        puts 'Generating LLM instructions...'
        puts "Found #{llm_endpoints.size} LLM instruction-enabled endpoint(s):"

        generator = RapiTapir::AI::LLMInstruction::Generator.new(llm_endpoints)
        instructions = generator.generate_all_instructions

        instructions[:instructions].each do |instruction|
          puts "\n#{'=' * 60}"
          puts "#{instruction[:method]} #{instruction[:path]} (#{instruction[:purpose]})"
          puts '=' * 60
          puts instruction[:instruction]
        end

        puts "\n#{'=' * 60}"
        puts "Generated #{instructions[:instructions].size} LLM instructions"
      end

      def run_llm_export(args)
        format = args.shift || 'json'
        output_file = @options[:output]

        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        endpoints = load_endpoints(@options[:input])
        llm_endpoints = endpoints.select(&:llm_instruction?)

        if llm_endpoints.empty?
          puts 'No LLM instruction-enabled endpoints found'
          exit 1
        end

        require_relative '../ai/llm_instruction'

        generator = RapiTapir::AI::LLMInstruction::Generator.new(llm_endpoints)
        instructions = generator.generate_all_instructions
        exporter = RapiTapir::AI::LLMInstruction::Exporter.new(instructions)

        case format.downcase
        when 'json'
          output = exporter.to_json
          extension = '.json'
        when 'yaml', 'yml'
          output = exporter.to_yaml
          extension = '.yml'
        when 'markdown', 'md'
          output = exporter.to_markdown
          extension = '.md'
        when 'prompts'
          if output_file
            puts exporter.to_prompt_files(output_file)
            return
          else
            puts 'Error: --output directory is required for prompts format'
            exit 1
          end
        else
          puts "Error: Unsupported format '#{format}'. Supported: json, yaml, markdown, prompts"
          exit 1
        end

        if output_file
          output_file += extension unless output_file.end_with?(extension)
          File.write(output_file, output)
          puts "LLM instructions exported to #{output_file}"
        else
          puts output
        end
      end

      def run_llm_test(args)
        purpose = args.shift

        unless purpose
          puts 'Usage: rapitapir ai llm test <purpose>'
          puts 'Available purposes: validation, transformation, analysis, documentation, testing, completion'
          exit 1
        end

        unless @options[:input]
          puts 'Error: --endpoints is required'
          exit 1
        end

        endpoints = load_endpoints(@options[:input])
        llm_endpoints = endpoints.select(&:llm_instruction?)

        if llm_endpoints.empty?
          puts 'No LLM instruction-enabled endpoints found'
          exit 1
        end

        require_relative '../ai/llm_instruction'

        puts "Testing LLM instruction generation for purpose: #{purpose}"
        puts

        generator = RapiTapir::AI::LLMInstruction::Generator.new(llm_endpoints)

        llm_endpoints.each do |endpoint|
          config = endpoint.llm_instruction_config.dup
          config[:purpose] = purpose.to_sym

          begin
            instruction = generator.generate_instruction(endpoint, config)
            puts "✅ #{endpoint.method&.upcase} #{endpoint.path}"
            puts "   Purpose: #{instruction[:purpose]}"
            puts "   Length: #{instruction[:instruction].length} characters"
            puts
          rescue StandardError => e
            puts "❌ #{endpoint.method&.upcase} #{endpoint.path}"
            puts "   Error: #{e.message}"
            puts
          end
        end
      end

      def ai_help
        <<~HELP
          AI Commands:
            rapitapir ai rag test [query]       - Test RAG functionality on your API
            rapitapir ai rag setup             - Create RAG configuration template
            rapitapir ai query <question>       - Get AI-ready context for a query
            rapitapir ai llm generate           - Generate LLM instructions from endpoints
            rapitapir ai llm export [format]    - Export LLM instructions (json, yaml, markdown, prompts)
            rapitapir ai llm test <purpose>     - Test LLM instruction generation for a purpose
            rapitapir ai help                   - Show this help
        HELP
      end
    end
  end
end
