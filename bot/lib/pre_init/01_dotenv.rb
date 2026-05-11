# frozen_string_literal: true

#
# Loads `.env` files into ENV.
#
# `Dotenv.overload` (rather than `Dotenv.load`) overwrites pre-existing ENV
# vars so the dotfile is the source of truth, not the shell. The base `.env`
# is always loaded; environment-specific overlays are layered on top so a
# value in `.env.production` wins over the same key in `.env`.
#

Dotenv.overload
Dotenv.overload(".env.test") if ENV["ESM_ENV"] == "test"
Dotenv.overload(".env.production") if ENV["ESM_ENV"] == "production"
