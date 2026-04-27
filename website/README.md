# Exile Server Manager (ESM) - Website

<p align="center">
	<a href="https://www.ruby-lang.org/en/">
		<img src="https://img.shields.io/badge/Ruby-v3.2.2-green.svg" alt="ruby version">
	</a>
	<a href="https://rubyonrails.org/">
		<img src="https://img.shields.io/badge/Rails-v8.0-red.svg" alt="rails version">
	</a>
	<a href="https://www.esmbot.com/releases">
		<img src="https://img.shields.io/badge/ESM-v2.0.1-blue.svg" alt="esm version">
	</a>
</p>

ESM's web dashboard provides a centralized interface for managing Exile servers and communities through Discord. Server owners can configure commands, manage notifications, and monitor their servers, while players can manage their accounts and XM8 notification routing - all from a modern, responsive web interface.

## Links

- [Live Website](https://esmbot.com)
- [Getting Started Guide](https://esmbot.com/getting_started)
- [Join our Discord](https://esmbot.com/join)
- [Invite ESM](https://esmbot.com/invite)

## Features

- **Server Management**: Configure server settings, mods, rewards, and gambling parameters
- **Command Configuration**: Enable/disable commands, set cooldowns, and manage permissions
- **Notification System**: Create custom Discord notifications with dynamic variables
- **XM8 Routing**: Players can route their game notifications to specific Discord channels
- **Account Management**: Link Steam/Discord accounts, create aliases, and set defaults
- **Real-time Updates**: Built with Hotwire for seamless, SPA-like interactions

---

## For Developers

This is the source code for ESM's web dashboard. If you're looking to install ESM for your Exile server, please visit our [Getting Started Guide](https://esmbot.com/getting_started).

### Requirements

- Ruby 3.2.2+
- PostgreSQL 15+
- Redis
- Node.js 18+ (for Vite)
- Understanding of:
  - Ruby on Rails
  - SLIM templating
  - Bootstrap 5.3
  - Hotwire (Turbo + Stimulus)
  - Active Record

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
git clone https://github.com/itsthedevman/esm_website
cd esm_website

# Install dependencies
bundle install
yarn install

# Setup environment
cp .env.example .env
# Edit .env with your configuration

# Initialize database
bin/setup

# Start development server
bin/assets &
bin/dev
```

### Core Systems

- **Authentication**: Discord OAuth with Devise
- **Authorization**: Role-based access control for communities and servers
- **View Layer**: SLIM templates with Bootstrap 5.3 styling
- **Interactivity**: Stimulus controllers for dynamic UI components
- **Real-time Updates**: Turbo Frames and Streams for SPA-like experience
- **Asset Pipeline**: Vite for modern JavaScript and CSS bundling

## License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>

ESM is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).
