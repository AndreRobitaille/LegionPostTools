# Be sure to restart your server when you modify this file.

require_relative "../../lib/middleware/no_index_header"

# Outermost so static files, Active Storage, and error pages are included.
Rails.application.config.middleware.unshift NoIndexHeader
