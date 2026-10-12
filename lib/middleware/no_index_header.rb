# Adds X-Robots-Tag to every response that passes through the Rails stack,
# including HTML, JSON, Active Storage, assets served by Rails, and errors.
# Crawlers can still fetch pages; this header tells them not to index or follow.
class NoIndexHeader
  HEADER = "x-robots-tag"
  VALUE = "noindex, nofollow"

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers = headers.dup if headers.frozen?
    headers[HEADER] = VALUE
    [ status, headers, body ]
  end
end
