require "test_helper"
require_relative "../support/chrome_detached_document"

class ChromeDetachedDocumentVisibilityTest < ActiveSupport::TestCase
  test "a detached document read is reported as a stale element" do
    error = assert_raises(Selenium::WebDriver::Error::StaleElementReferenceError) do
      probe(ChromeDetachedDocumentVisibility::DETACHED_DOCUMENT_MESSAGE).visible?
    end

    assert_includes error.message, ChromeDetachedDocumentVisibility::DETACHED_DOCUMENT_MESSAGE
  end

  test "other Chrome unknown errors still fail immediately" do
    assert_raises(Selenium::WebDriver::Error::UnknownError) do
      probe("chrome not reachable").visible?
    end
  end

  private

  def probe(message)
    Class.new do
      prepend ChromeDetachedDocumentVisibility

      define_method(:visible?) do
        raise Selenium::WebDriver::Error::UnknownError, "unknown error: unhandled inspector error: #{message}"
      end
    end.new
  end
end
