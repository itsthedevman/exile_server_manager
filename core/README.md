# Exile Server Manager (ESM) - Ruby Core

<p align="center">
	<a href="https://www.ruby-lang.org/en/">
		<img src="https://img.shields.io/badge/Ruby-v3.3-green.svg" alt="ruby version">
	</a>
	<a href="https://rubygems.org/">
		<img src="https://img.shields.io/badge/Gem-v2.0.0-orange.svg" alt="gem version">
	</a>
</p>

ESM Ruby Core is an internal shared library containing the core models, utilities, and business logic used across ESM's Ruby applications. This gem ensures consistency between the Discord bot and website.

> **Note**: This is an internal ESM component. If you're looking to use ESM with your Exile server, please visit [esmbot.com/getting_started](https://esmbot.com/getting_started).

---

## Installation

Add to your application's Gemfile:

```ruby
gem "esm_ruby_core", github: "https://github.com/itsthedevman/esm_ruby_core"
```

Then execute:

```bash
bundle install
```

## For Developers

This gem contains the shared foundation for all ESM Ruby applications. Changes here affect both the Discord bot and website.

### Requirements

- Ruby 3.3+
- Understanding of:
  - Active Record
  - Ruby gems
  - PostgreSQL

### Setup

#### Method 1: Using Nix (Recommended)

```bash
# Install nix and direnv
# Enable flakes in your nix config
direnv allow
```

#### Method 2: Manual Setup

```bash
# Clone the repository
git clone https://github.com/itsthedevman/esm_ruby_core
cd esm_ruby_core

# Install dependencies
bin/setup

# Run console for testing
bin/console
```

## License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>

ESM is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).
