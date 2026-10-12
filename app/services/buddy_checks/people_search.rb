module BuddyChecks
  class PeopleSearch
    def initialize(people)
      @people = people
    end

    def call(query)
      query = query.to_s.split(/[[:space:]]+/).reject(&:empty?).join(" ")
      raise ArgumentError unless query.length.between?(2, 80)
      tokens = query.downcase.split(" ")
      ordinary = tokens.reduce(@people) do |scope, token|
        scope.where("first_name ILIKE :q OR last_name ILIKE :q", q: "%#{Person.sanitize_sql_like(token)}%")
      end
      return ordinary if ordinary.exists?
      return @people.none unless tokens.any? { |token| typo_word?(token) }

      ids = []
      @people.select(:id, :first_name, :last_name).find_each do |person|
        ids << person.id if typo_match?(person, tokens)
      end
      @people.where(id: ids)
    end

    private

    def typo_word?(token)
      token.match?(/\A[[:alpha:]]{4,}\z/)
    end

    def typo_match?(person, tokens)
      names = [ person.first_name.downcase, person.last_name.downcase ]
      unmatched = tokens.reject { |token| names.any? { |name| name.include?(token) } }
      return false unless unmatched.one? && typo_word?(unmatched.first)

      names.flat_map { |name| name.scan(/[[:alpha:]]+/) }.any? { |word| one_edit_apart?(unmatched.first, word) }
    end

    def one_edit_apart?(token, word)
      return false if word.length < 4 || (token.length - word.length).abs > 1
      left, right = token.chars, word.chars
      if left.length == right.length
        different = left.each_index.select { |index| left[index] != right[index] }
        return true if different.one?
        return false unless different.size == 2
        first, last = different
        last == first + 1 && left[first] == right[last] && left[last] == right[first]
      else
        shorter, longer = left.length < right.length ? [ left, right ] : [ right, left ]
        index = shorter.each_index.find { |position| shorter[position] != longer[position] } || shorter.length
        longer.delete_at(index)
        shorter == longer
      end
    end
  end
end
