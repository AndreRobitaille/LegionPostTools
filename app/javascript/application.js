// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import * as Lexxy from "lexxy"

Lexxy.configure({
  default: {
    attachments: false
  }
})
