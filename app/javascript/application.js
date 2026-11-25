// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// An iPad can identify as a Mac even when its primary pointer is a trackpad.
if (navigator.maxTouchPoints > 1) document.documentElement.classList.add("has-multitouch")

import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import * as Lexxy from "lexxy"

Lexxy.configure({
  default: {
    attachments: false
  }
})
