# Chrome sometimes reports a node from a document that navigation has already
# replaced as UnknownError ("Node with given id does not belong to the document")
# instead of StaleElementReferenceError. Capybara 3.40 retries only the latter, so
# a finder aborts in the middle of its wait. Visibility checks are reads: report
# this one inspector message as a stale element so the existing wait looks the
# node up again. Other UnknownErrors still fail on the first attempt, and clicks
# are left alone so a delivered action is not repeated.
module ChromeDetachedDocumentVisibility
  DETACHED_DOCUMENT_MESSAGE = "Node with given id does not belong to the document"

  def visible?
    super
  rescue Selenium::WebDriver::Error::UnknownError => error
    raise error unless error.message.include?(DETACHED_DOCUMENT_MESSAGE)

    raise Selenium::WebDriver::Error::StaleElementReferenceError, error.message
  end
end

require "capybara/selenium/nodes/chrome_node"

unless Capybara::Selenium::ChromeNode.ancestors.include?(ChromeDetachedDocumentVisibility)
  Capybara::Selenium::ChromeNode.prepend(ChromeDetachedDocumentVisibility)
end
