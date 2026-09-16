module PdfResourcePolicy
  extend ActiveSupport::Concern

  STYLESHEETS = %w[lexxy.css lexxy-content.css lexxy-editor.css lexxy-variables.css tailwind.css].freeze

  included do
    before_action :restrict_pdf_resources
    helper_method :pdf_document?
  end

  private

  def pdf_document?
    true
  end

  def restrict_pdf_resources
    request.content_security_policy_nonce_generator = ->(_) { SecureRandom.base64(32) }
    request.content_security_policy_nonce_directives = %w[style-src]
    request.content_security_policy_report_only = false
    # Production AssumeSSL marks this request HTTPS, but Chromium and its relative
    # asset requests use the original HTTP loopback host and port.
    asset_host = "http://#{request.raw_host_with_port}"
    request.content_security_policy = ActionDispatch::ContentSecurityPolicy.new do |policy|
      policy.default_src :none
      policy.base_uri :none
      policy.form_action :none
      policy.frame_ancestors :none
      policy.img_src helpers.asset_url("al-emblem.png", host: asset_host)
      policy.style_src(*STYLESHEETS.map { |asset| helpers.asset_url(asset, host: asset_host) })
      policy.style_src_attr :unsafe_inline
    end
  end
end
