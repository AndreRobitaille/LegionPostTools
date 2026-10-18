require "uri"

# Public installation identity only. Never derive preview URLs from a request.
class MembersSite
  attr_reader :name, :description, :origin, :image_path, :image_alt

  def initialize(env = ENV)
    @name = env.fetch("MEMBERS_SITE_NAME", "Post Members")
    @description = env.fetch("MEMBERS_SITE_DESCRIPTION", "Meeting agendas, minutes, and member resources for your American Legion Post. Member sign-in required.")
    @image_alt = env.fetch("MEMBERS_SITE_IMAGE_ALT", "American Legion Post Members")
    @image_path = env.fetch("MEMBERS_SITE_IMAGE_PATH", "/members/members-og.jpg")
    configured_origin = env.fetch("MEMBERS_SITE_ORIGIN") { "https://#{env.fetch('APP_HOST', 'example.invalid')}" }
    uri = URI.parse(configured_origin)
    unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? &&
        uri.path.in?([ "", "/" ]) && uri.query.nil? && uri.fragment.nil?
      raise ArgumentError, "MEMBERS_SITE_ORIGIN must be an HTTPS origin without credentials, path, query, or fragment"
    end
    unless image_path.match?(%r{\A/members/(?:[a-z0-9_-]+/)*[a-z0-9_-]+\.jpg\z})
      raise ArgumentError, "MEMBERS_SITE_IMAGE_PATH must be a local JPEG under /members/"
    end
    @origin = configured_origin.delete_suffix("/")
  rescue URI::InvalidURIError
    raise ArgumentError, "MEMBERS_SITE_ORIGIN must be a valid HTTPS origin"
  end

  def entry_url = "#{origin}/"
  def image_url = "#{origin}#{image_path}"
end
