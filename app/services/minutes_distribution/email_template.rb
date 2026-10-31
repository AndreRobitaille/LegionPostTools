module MinutesDistribution::EmailTemplate
  VARIABLES = {
    "post_name" => "Post name", "post_label" => "Short Post name",
    "meeting_name" => "Meeting name", "meeting_label" => "Full meeting title",
    "meeting_date" => "Meeting date", "copy_label" => "Copy label"
  }.freeze
  TOKEN = /\{\{\s*([a-z_]+)\s*\}\}/
  DEFAULT_SUBJECT = "{{post_label}} · {{copy_label}} · {{meeting_name}} · {{meeting_date}}".freeze
  DEFAULT_COVER_NOTE = "Open the attached PDF to read, save or print the minutes.".freeze
  LEGACY_SUBJECT = "{{post_name}} — {{copy_label}} — {{meeting_label}} — {{meeting_date}}".freeze
  LEGACY_COVER_NOTE = "Attached are the minutes of our {{meeting_label}} held on {{meeting_date}}.".freeze
  CORRECTION_NOTICE = "This is a corrected copy. This copy replaces the earlier copy.".freeze

  module_function

  def problems(text)
    names = text.to_s.scan(TOKEN).flatten
    errors = (names - VARIABLES.keys).uniq.map { |name| "Unknown variable {{#{name}}}. Use a variable shown below." }
    remainder = text.to_s.gsub(TOKEN, "")
    errors << "Use complete variables such as {{meeting_date}}." if remainder.include?("{{") || remainder.include?("}}")
    errors
  end

  def render(text, values)
    text.gsub(TOKEN) { values.fetch(Regexp.last_match(1)) }
  end

  # Existing distributions predate saved wording; keep their original standard copy.
  def legacy_wording(corrected:)
    note = corrected ? "Attached are the corrected minutes of our {{meeting_label}} held on {{meeting_date}}. This copy replaces the earlier copy." : LEGACY_COVER_NOTE
    { "subject" => LEGACY_SUBJECT, "cover_note" => note }
  end
end
