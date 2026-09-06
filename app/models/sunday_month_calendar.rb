class SundayMonthCalendar < SimpleCalendar::MonthCalendar
  def date_range
    (start_date.beginning_of_month.beginning_of_week(:sunday)..start_date.end_of_month.end_of_week(:sunday)).to_a
  end
end
