# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-11-22

### Summary
Dependency refresh to the latest gem releases, with code adaptations for
breaking API changes, and a full repair of the example catalog.

### Added
- 📦 **jwt runtime dependency declared in the gemspec** (`>= 2.10, < 4.0`) — it was lazily `require`d by `RapiTapir::Auth` OAuth2 validation but never declared, so installs could silently lack it

### Changed
- 🔢 **Bumped all dependencies to their latest releases**: dotenv 3.2, json 3.1, jwt 3.3, rack 3.2, puma 8.1, simplecov 1.3, sinatra 4.2, webmock 3.38, rubocop 1.92, rackup 2.3, rack-test 2.3, rspec 3.13, webrick 1.9, OpenTelemetry exporter-otlp 0.37 / instrumentation-all 0.102 / sdk 1.13
- 🐾 **Minimum Ruby raised to 3.3** (`required_ruby_version >= 3.3`). The latest OpenTelemetry stack (api 1.9+, sdk 1.11+, common 0.24+) declares `ruby >= 3.3`; keeping the current otel releases required dropping the EOL 3.1/3.2 runtimes. CI matrix and all workflows now test 3.3/3.4. **This is a breaking change for Ruby 3.1/3.2 users.**
- ⬆️ **json range widened in the gemspec** to `>= 2.6, < 4.0` to match the refreshed stack
- 🧩 **JWT v3 compatibility**: `JWT.decode` no longer accepts the positional `verify` argument — replaced with the `verify_signature: true` option (works on jwt ≥ 2.10 and 3.x)
- 🎨 **RuboCop 1.92 compliance**: `Style/DirectiveScope` disable/enable pairs converted to `disable-next`

### Fixed
- 📚 **`examples/enterprise_rapitapir_api.rb`**: `configure`/`set` were called from an instance `initialize` (crash on boot); auth/middleware setup moved to class level; `SinatraAdapter` now binds to the app class (Sinatra 4 removed instance→class delegation); handlers use the adapter's `[status, headers, body]` response protocol
- 📚 **`examples/enterprise_extension_demo.rb`**: `bearer_auth` → `add_auth_scheme(:bearer, RapiTapir::Auth.bearer_token(...))` (the real `Configuration` API)
- 📚 **`examples/demo_api.rb`, `simple_demo_api.rb`, `cli/user_api_endpoints.rb`, `user_api.rb`, `production_ready_example.rb`**: rewritten from the removed `.in/.out/.error_out` DSL onto the current builder (`json_body`, `ok`, `created`, `no_content`, `not_found`, …) with proper `RapiTapir::Types.hash/array` types
- 📚 **`examples/auto_derivation_ruby_friendly.rb`**: now demos only the real derivation APIs (`from_hash`, `from_open_struct`, `from_json_schema`, `from_protobuf`)
- 🧪 **All 18 examples verified running**, including live HTTP checks of the three server examples

### Verification
- ✅ 695 RSpec examples, 0 failures
- ✅ RuboCop: 91 files, no offenses
- ✅ `gem build` produces a clean installable package

## [Unreleased] - 2025-08-02

### Summary
This release introduces the **SinatraRapiTapir** base class, providing the cleanest possible syntax for creating RapiTapir APIs. The new inheritance-based approach eliminates boilerplate while maintaining 100% backward compatibility.

### Added - SinatraRapiTapir Base Class & Enhanced Developer Experience
- 🎯 **SinatraRapiTapir Base Class**: Clean inheritance syntax `class MyAPI < SinatraRapiTapir`
- ✨ **Enhanced HTTP Verb DSL**: Built-in GET, POST, PUT, DELETE methods with fluent chaining
- 🔧 **Automatic Extension Registration**: Zero-boilerplate setup with automatic feature inclusion
- � **Type Shortcuts**: Global `T` constant for cleaner type syntax (`T.string` vs `RapiTapir::Types.string`)
- �📖 **Comprehensive Documentation**: Added detailed guides for base class usage and setup
- 🚀 **GitHub Pages Deployment**: Modern workflow with build/deploy separation for documentation
- 🧪 **Enhanced Test Suite**: Complete test coverage for SinatraRapiTapir functionality
- 📋 **Setup Guides**: Step-by-step documentation for GitHub Pages and repository configuration

### Enhanced
- 🔄 **Examples Updated**: Hello World and Getting Started examples now use clean base class syntax
- 📚 **Documentation Structure**: Improved organization with separate guides for each feature
- 🛠️ **Developer Experience**: Cleaner API with fewer required imports and automatic setup
- � **Type Syntax**: Introduced global `T` shortcut for much cleaner type definitions
- �🔧 **GitHub Actions**: Fixed workflow permissions and modernized deployment pattern

### Fixed
- 📄 **GitHub Pages Deployment**: Resolved 404 errors with proper workflow configuration
- 🔒 **Workflow Permissions**: Added required `pages: write` and `id-token: write` permissions
- ⚙️ **YAML Syntax**: Simplified HTML generation to prevent parsing conflicts
- 🏗️ **Build Pipeline**: Separated build and deploy jobs for better error handling

### Technical Improvements
- **Backward Compatibility**: 100% compatible with existing manual extension registration
- **Top-level Constant**: `SinatraRapiTapir` available at both module and top level
- **Automatic Features**: Health checks, CORS, documentation, and middleware auto-enabled
- **Development Messages**: Helpful startup messages indicating active features

### Documentation
- `docs/sinatra_rapitapir.md` - Complete base class usage guide
- `docs/github_pages_setup.md` - Repository configuration instructions  
- `docs/github_pages_fix.md` - Workflow troubleshooting guide
- Updated examples demonstrating clean syntax patterns

### Breaking Changes
- None - all changes are additive and backward compatible

### Migration Guide
- **New Projects**: Use `class MyAPI < SinatraRapiTapir` for cleanest syntax
- **Existing Projects**: Continue using manual extension registration (no changes required)
- **Enhanced DSL**: Access GET, POST, etc. methods directly without additional setup

## [0.1.0] - 2024-08-01

### Added
- 🎉 Initial release of RapiTapir
- 🏗️ Core DSL for defining HTTP endpoints
- 🔧 Type system with validation and coercion
- 📚 Automatic OpenAPI documentation generation
- 🚀 Sinatra integration with ResourceBuilder
- 🔒 Authentication and authorization framework
- 📊 Health check and observability features
- 🧪 Comprehensive test suite (100% passing)
- 📖 Complete documentation and examples
- 🤝 Community-ready repository structure

### Features
- **Declarative API Design**: Define endpoints with `.in()`, `.out()`, `.error_out()` chaining
- **Type Safety**: Strong typing with automatic validation and helpful error messages
- **Framework Integration**: Seamless Sinatra support with plans for Rails and Rack
- **Documentation Generation**: Auto-generated OpenAPI 3.0 specs and interactive SwaggerUI
- **Client Generation**: TypeScript client generation with more languages planned
- **Enterprise Ready**: Built-in authentication, rate limiting, and security headers
- **Developer Experience**: Intuitive DSL, comprehensive examples, and excellent error messages

### Examples
- Basic getting started example with books API
- Enterprise example with authentication and advanced features
- CRUD operations with elegant block syntax
- Health checks and monitoring integration

### Technical Details
- **Ruby Compatibility**: Supports Ruby 3.1+
- **Framework Support**: Sinatra 2.0+, with Rack 2.0+ compatibility
- **Test Coverage**: 470 tests passing (100% success rate) with 70.13% coverage
- **Documentation**: Complete API docs, tutorials, and contribution guidelines  
- **Code Quality**: Professional codebase following Ruby best practices
- **Developer Experience**: Clean inheritance syntax with automatic feature setup

[Unreleased]: https://github.com/riccardomerolla/rapitapir/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/riccardomerolla/rapitapir/releases/tag/v0.1.0
