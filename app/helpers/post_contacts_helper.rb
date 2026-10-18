module PostContactsHelper
  def post_contact_phone_href(phone)
    number, extension = phone.to_s.split(/\s*(?:ext\.?|x|#)\s*/i, 2)
    number = number.to_s.gsub(/[^\d+]/, "")
    return if number.delete("+").blank?

    extension = extension.to_s.gsub(/\D/, "")
    "tel:#{number}#{";ext=#{extension}" if extension.present?}"
  end
end
