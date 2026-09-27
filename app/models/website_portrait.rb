require "vips"

class WebsitePortrait < ApplicationRecord
  belongs_to :website_publication
  before_validation -> { self.revision ||= SecureRandom.hex(16) }
  validates :revision, :small, :large, presence: true

  def self.prepare(upload)
    raise ArgumentError, "Choose a JPEG, PNG or WebP image under 10 MiB." if upload.size > 10.megabytes
    bytes = upload.read(10.megabytes + 1)
    supported = bytes.start_with?("\xFF\xD8\xFF".b, "\x89PNG\r\n\x1A\n".b) || (bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP")
    raise ArgumentError, "Choose a JPEG, PNG or WebP image." unless supported

    source = Vips::Image.new_from_buffer(bytes, "", access: :sequential)
    unless source.width.between?(320, 12_000) && source.height.between?(400, 12_000) && source.width * source.height <= 40_000_000 && (!source.get_fields.include?("n-pages") || source.get("n-pages") == 1)
      raise ArgumentError, "Use a single image at least 320 × 400, no larger than 40 megapixels."
    end
    renditions = { small: [ 320, 400 ], large: [ 640, 800 ] }.transform_values do |width, height|
      Vips::Image.thumbnail_buffer(bytes, width, height: height, size: :both, crop: :centre)
        .write_to_buffer(".webp", Q: 85, strip: true)
    end
    raise ArgumentError, "The prepared portrait is too large." if renditions.values.any? { |value| value.bytesize > 2.megabytes }
    renditions
  rescue Vips::Error
    raise ArgumentError, "This image could not be read. Choose another JPEG, PNG or WebP."
  end
end
