# A navigation convenience, never an authorization grant. The target controller
# checks the newly signed-in member's current permissions on the next GET.
class SignInReturnPath
  SESSION_KEY = :navigation_return_to
  TTL = 15.minutes
  NAVIGATION_PATHS = [
    %r{\A/(?:dashboard|profile|officer-tools)?\z},
    %r{\A/meetings(?:/[1-9]\d*(?:/minutes)?)?\z},
    %r{\A/dated_agendas(?:/[1-9]\d*)?\z},
    %r{\A/people(?:/[1-9]\d*)?\z},
    %r{\A/endeavors(?:/[1-9]\d*)?\z},
    %r{\A/calendar\z},
    %r{\A/calendar_events/[1-9]\d*\z},
    %r{\A/admin(?:/meetings(?:/[1-9]\d*(?:/minutes)?)?)?\z},
    %r{\A/admin/dated_agendas/[1-9]\d*/(?:edit|commander)\z}
  ].freeze

  def self.allowed?(path)
    path.is_a?(String) && NAVIGATION_PATHS.any? { |pattern| pattern.match?(path) }
  end

  def self.capture(request)
    return unless request.get? && request.format.html? && allowed?(request.path)

    { "path" => request.path, "expires_at" => TTL.from_now.to_i }
  end

  def self.destination(saved)
    return unless saved.is_a?(Hash) && allowed?(saved["path"])
    return unless saved["expires_at"].is_a?(Integer) && saved["expires_at"] > Time.current.to_i

    saved["path"]
  end
end
