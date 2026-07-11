WebAuthn.configure do |config|
  config.allowed_origins = [ENV.fetch("WEBAUTHN_ORIGIN", Rails.env.production? ? nil : "http://localhost:3000")]
  config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", Rails.env.production? ? nil : "LegionPostTools")
  config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", Rails.env.production? ? nil : "localhost")
end
