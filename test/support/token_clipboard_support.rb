module TokenClipboardSupport
  def assert_token_copied_to_clipboard(plaintext)
    browser = page.driver.browser
    begin
      browser.add_permissions("clipboard-read" => "granted", "clipboard-write" => "granted")
      assert_equal true, write_synthetic_clipboard("SYNTHETIC-STALE-COPY-121")
      click_button "Copy token"
      assert_selector "[data-copy-token-target='status'][data-state='success']", text: "Token copied."
      copied = page.evaluate_async_script(<<~JS)
        const done = arguments[arguments.length - 1];
        navigator.clipboard.readText().then(done, error => done({ error: error.name }));
      JS
      assert_equal plaintext, copied

      browser.add_permission("clipboard-write", "denied")
      click_button "Copy token"
      assert_selector "[data-copy-token-target='status'][data-state='error']", text: "The token is selected so you can copy it manually."
      selection = page.evaluate_script(<<~JS)
        (() => {
          const source = document.querySelector('[data-copy-token-target="source"]');
          return { focused: document.activeElement === source, start: source.selectionStart, end: source.selectionEnd, value: source.value };
        })()
      JS
      assert_equal({ "focused" => true, "start" => 0, "end" => plaintext.length, "value" => plaintext }, selection)
    ensure
      begin
        browser.add_permission("clipboard-write", "granted")
        write_synthetic_clipboard("SYNTHETIC-CLEARED-COPY-121")
      ensure
        browser.execute_cdp("Browser.resetPermissions")
      end
    end
  end

  private

  def write_synthetic_clipboard(value)
    page.evaluate_async_script(<<~JS, value)
      const done = arguments[arguments.length - 1];
      navigator.clipboard.writeText(arguments[0]).then(() => done(true), error => done({ error: error.name }));
    JS
  end
end
