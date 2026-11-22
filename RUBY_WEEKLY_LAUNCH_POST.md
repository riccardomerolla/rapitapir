# 🦙 Introducing RapiTapir: Type-Safe HTTP APIs for Ruby

TL;DR: RapiTapir brings Tapir-style, declarative, type-safe APIs to Ruby with a clean DSL, automatic OpenAPI docs, a TypeScript client, and a new one-command scaffold from an OpenAPI spec.

## The Problem: Ruby API Development Pain Points

Ruby developers love the language's expressiveness, but API development often involves:

- **Manual documentation** that gets out of sync with code
- **Runtime errors** from type mismatches that could be caught earlier  
- **Boilerplate code** for validation, serialization, and error handling
- **Inconsistent patterns** across different teams and projects

What if we could have the type safety of languages like Scala while keeping Ruby's elegance?

## Enter RapiTapir 🦙

RapiTapir is inspired by [Scala's Tapir](https://github.com/softwaremill/tapir), bringing **declarative, type-safe API development** to Ruby. Define your endpoints once with strong typing, and get automatic validation, documentation, and client generation.

### The Magic: Clean Base Class Syntax

```ruby
require 'rapitapir'

class BookAPI < RapiTapir::SinatraRapiTapir
  rapitapir do
    info(title: 'Book API', version: '1.0.0')
    development_defaults! # health checks, CORS, docs
  end

  # T shortcut available globally
  BOOK_SCHEMA = T.hash({
    "id" => T.integer,
    "title" => T.string(min_length: 1, max_length: 255),
    "author" => T.string(min_length: 1),
    "published" => T.boolean,
    "isbn" => T.optional(T.string),
    "pages" => T.optional(T.integer(minimum: 1))
  })

  endpoint(
    GET('/books')
      .query(:limit, T.optional(T.integer(minimum: 1, maximum: 100)))
      .query(:genre, T.optional(T.string))
      .summary('List books with filtering')
      .ok(T.array(BOOK_SCHEMA))
      .build
  ) do |inputs|
    Book.where(genre: inputs[:genre])
        .limit(inputs[:limit] || 20)
        .map(&:to_h)
  end
end
```

Start the server and visit `http://localhost:4567/docs` for **interactive Swagger documentation** that's always in sync with your code.

## Why RapiTapir Feels Like Ruby Magic ✨

### 1. **Zero Boilerplate Setup**
```ruby
# One line to get a complete API server
class MyAPI < SinatraRapiTapir
  # Enhanced HTTP verbs automatically available
  # T shortcut for types works everywhere
  # Health checks, CORS, docs - all included
end
```

### 2. **Type Safety Without Ceremony**
```ruby
# Define once, use everywhere
USER_SCHEMA = T.hash({
  "email" => T.email,  # built-in email validation
  "age" => T.optional(T.integer(minimum: 0, maximum: 150))
})

# Automatic validation + coercion
endpoint(POST('/users').json_body(USER_SCHEMA).build) do |inputs|
  User.create(inputs[:body])
end
```

### 3. **RESTful Resources Made Simple**
```ruby
# Complete CRUD API in ~10 lines
api_resource '/books', schema: BOOK_SCHEMA do
  crud do
    index { Book.all }
    show { |inputs| Book.find(inputs[:id]) }
    create { |inputs| Book.create(inputs[:body]) }
    update { |inputs| Book.update(inputs[:id], inputs[:body]) }
    destroy { |inputs| Book.destroy(inputs[:id]); status 204 }
  end
  
  # Add custom endpoints with full type safety
  custom :get, 'featured' do
    Book.where(featured: true)
  end
end
```

## From OpenAPI to Running App (Scaffold)

Input: an OpenAPI/Swagger JSON.

Output: a runnable SinatraRapiTapir + ActiveRecord + SQLite app with:
- config.ru, Rakefile, Gemfile
- app/api/app.rb (endpoints mapped; docs, tags, descriptions, and security reflected)
- app/models, db/migrate, config/database.yml
- health check and docs enabled by default

Try it:

```bash
rapitapir generate scaffold --from openapi.json --out ./my_api
cd my_api
bundle install
bundle exec rake db:create db:migrate
bundle exec rackup
```

## Production-Ready Features 🛡️

- Development defaults: health checks, CORS, and docs out of the box.
- Security headers: header-based API keys in your OpenAPI are scaffolded and reflected in docs.
- Observability: health endpoint enabled; metrics/tracing integration planned.

## Real-World Benefits

**🚀 Development Speed**: Define endpoints declaratively, get validation + docs for free

**🐛 Fewer Bugs**: Type checking catches issues at definition time, not runtime

**📖 Always-Current Docs**: Swagger UI generated from your actual code

**🔧 Better DX**: Enhanced error messages, auto-completion, consistent patterns

**⚡ Easy Testing**: Validate schemas independently, generate test fixtures

## Framework Integration

Works with your existing Ruby stack:

```ruby
# Sinatra (recommended) - clean inheritance
class API < RapiTapir::SinatraRapiTapir; end

# Sinatra extension
register RapiTapir::Sinatra::Extension
```

## The Ruby Community Connection

RapiTapir builds on Ruby's strengths:

- **Sinatra's simplicity** with enhanced capabilities
- **Rack's composability** for middleware and deployment  
- **Ruby's expressiveness** with added type safety
- **Community gems** for auth, testing, deployment

It's not about replacing your stack - it's about making it better.

## Getting Started

```bash
gem install rapitapir
```

Or add to your Gemfile:
```ruby
gem 'rapitapir'
```

Check out the examples and docs:
- Examples: https://github.com/riccardomerolla/rapitapir/tree/main/examples
- Docs: https://riccardomerolla.github.io/rapitapir

## What’s Next?

- Rails integration for seamless adoption in existing apps
- More client generators (Python, Go)
- Enhanced observability and tracing
- Plugin ecosystem for community extensions

## Try It Today

RapiTapir is **production-ready** with comprehensive tests, clear documentation, and real-world examples. Whether you're building a new API or enhancing an existing one, RapiTapir helps you write better Ruby code.

**Links:**
- Gem: https://rubygems.org/gems/rapitapir
- Homepage: https://riccardomerolla.github.io/rapitapir
- Source: https://github.com/riccardomerolla/rapitapir
- Docs: https://github.com/riccardomerolla/rapitapir/tree/main/examples

---

*Built with ❤️ for the Ruby community. Questions? Feedback? Open an issue or discussion on GitHub!*

**RapiTapir** - APIs so clean and fast, they practically run wild! 🦙⚡
