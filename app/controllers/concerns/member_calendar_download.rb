module MemberCalendarDownload
  extend ActiveSupport::Concern

  private

  def respond_with_calendar_entry(entry, preview: nil)
    @calendar_export = MemberCalendarExport.new(entry, detail_url: polymorphic_url(entry, preview: preview))
    respond_to do |format|
      format.html
      format.ics do
        no_store
        if @calendar_export.available?
          send_data @calendar_export.to_ics, type: "text/calendar; charset=utf-8",
            filename: "#{entry.model_name.singular}-#{entry.id}.ics", disposition: "attachment"
        else
          head :not_found
        end
      end
    end
  end
end
