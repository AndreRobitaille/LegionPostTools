module RosterImportsHelper
  def roster_change_details(change)
    delta_details(change).concat(transition_details(change)).join("; ")
  end

  private

  def delta_details(change)
    change.fetch("deltas", {}).sort_by { |delta, _count| delta.to_i }.map do |delta, count|
      direction = delta.to_i.negative? ? "decreased" : "increased"
      "#{pluralize(count, 'member')} #{direction} by #{delta.to_i.abs}"
    end
  end

  def transition_details(change)
    change.fetch("transitions", []).sort_by { |transition| [ -transition["count"].to_i, transition["from"].to_s ] }.map do |transition|
      "#{pluralize(transition['count'], 'member')} changed from #{transition['from']} to #{transition['to']}"
    end
  end
end
