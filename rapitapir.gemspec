# frozen_string_literal: true

require_relative 'lib/rapitapir/version'

Gem::Specification.new do |spec|
  spec.name = 'rapitapir'
  spec.version = RapiTapir::VERSION
  spec.authors = ['Riccardo Merolla']
  spec.email = ['riccardo.merolla@gmail.com']

  spec.summary = 'Type-safe HTTP API development for Ruby'
  spec.description = <<~DESC
    RapiTapir is a Ruby library inspired by Scala's Tapir for building type-safe HTTP APIs.#{' '}
    It provides declarative endpoint definitions, automatic OpenAPI documentation generation,#{' '}
    client code generation, and seamless integration with Sinatra, Rails, and Rack applications.
  DESC

  spec.homepage = 'https://riccardomerolla.github.io/rapitapir/'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/riccardomerolla/rapitapir'
  spec.metadata['changelog_uri'] = 'https://github.com/riccardomerolla/rapitapir/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://riccardomerolla.github.io/rapitapir/docs'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/riccardomerolla/rapitapir/issues'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[
                                                           bin/ test/ spec/ features/ .git .github appveyor Gemfile
                                                         ])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'json', '>= 2.6', '< 4.0'
  spec.add_dependency 'rack', '>= 2.0', '< 4.0'
  spec.add_dependency 'webrick', '~> 1.7'
  spec.add_dependency 'jwt', '>= 2.10', '< 4.0'

  # Optional framework dependencies
  spec.add_dependency 'sinatra', '>= 2.0', '< 5.0'

  # Development dependencies
  spec.add_development_dependency 'puma', '~> 6.0'
  spec.add_development_dependency 'rack-test', '~> 2.1'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'webmock', '~> 3.19'

  # Documentation
  spec.add_development_dependency 'redcarpet', '~> 3.6'
  spec.add_development_dependency 'yard', '~> 0.9'

  # Code quality
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-performance', '~> 1.18'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
