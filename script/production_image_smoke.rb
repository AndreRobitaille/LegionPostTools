# Executed inside the final production image with synthetic inputs and no database.
require_relative "../config/environment"
require "tmpdir"
require "vips"

abort "Expected production" unless Rails.env.production?
excluded = %w[capybara selenium-webdriver debug brakeman rubocop kamal sshkit net-ssh]
present = Gem::Specification.map(&:name) & excluded
abort "Non-runtime gems installed: #{present.join(', ')}" if present.any?
abort "No compiled assets" unless Dir["/rails/public/assets/*"].any?

Dir.mktmpdir("production-image-smoke") do |directory|
  html = File.join(directory, "synthetic.html")
  File.write(html, "<!doctype html><html><body><h1>Synthetic Post calendar</h1><p>Build verification only.</p></body></html>")
  pdf = BrowserPdfRenderer.render(source_url: "file://#{html}", temp_prefix: "production-image-pdf")
  abort "PDF rendering failed" unless pdf.start_with?("%PDF") && pdf.bytesize > 1_000

  image = Vips::Image.black(16, 16).pngsave_buffer
  abort "Image processing failed" unless image.start_with?("\x89PNG".b)
  puts "Production Rails boot, excluded gems, assets, Chromium PDF (#{pdf.bytesize} bytes), and libvips passed."
end
