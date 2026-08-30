module MinutesDrafting
  class SourceDocument
    MAX_LINE_LENGTH = 700

    attr_reader :lines

    def initialize(text)
      @lines = build_lines(text.to_s)
      raise ArgumentError, "Transcript source is empty" if @lines.empty?
    end

    def rendered
      lines.each_with_index.map { |line, index| format("L%04d %s", index + 1, line) }.join("\n")
    end

    def excerpt(start_line, end_line)
      selected = lines[(start_line - 1)..(end_line - 1)]
      raise IndexError, "Source range does not exist" if selected.blank?
      selected.each_with_index.map { |line, index| format("L%04d %s", start_line + index, line) }.join("\n")
    end

    private

    def build_lines(text)
      text.encode("UTF-8").gsub("\r\n", "\n").gsub("\r", "\n").lines(chomp: true).flat_map do |line|
        normalized = line.squish
        next [] if normalized.empty?
        next [ normalized ] if normalized.length <= MAX_LINE_LENGTH

        split_long_line(normalized)
      end
    end

    def split_long_line(line)
      sentences = line.scan(/.+?(?:[.!?](?=\s|\z)|\z)/).map(&:strip).reject(&:empty?)
      sentences = [ line ] if sentences.empty?

      sentences.flat_map { |sentence| split_oversized(sentence) }.each_with_object([]) do |part, packed|
        if packed.last && packed.last.length + part.length + 1 <= MAX_LINE_LENGTH
          packed[-1] = "#{packed.last} #{part}"
        else
          packed << part
        end
      end
    end

    def split_oversized(text)
      text.scan(/.{1,#{MAX_LINE_LENGTH}}(?:\s+|\z)|.{1,#{MAX_LINE_LENGTH}}/).map(&:strip)
    end
  end
end
