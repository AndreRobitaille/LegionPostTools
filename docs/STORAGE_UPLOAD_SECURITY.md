# Storage upload boundary

The application's supported attachments are restricted text transcripts and staged roster
CSVs. Both enter through capability-protected application controllers and are attached on
the server. Lexxy attachment uploads are disabled. There is no supported direct-to-storage
upload flow for either members or anonymous visitors.

The application therefore owns `ActiveStorage::DirectUploadsController#create` and returns
an empty 404 without creating a blob or issuing a signed upload capability. Keep the engine
routes and URL helpers: Lexxy uses those helpers even with attachments disabled, and the
server-side attachment lifecycle still uses Active Storage. This closes the anonymous
blob-creation/storage-exhaustion path without changing forms or upload feedback.

Existing signed disk upload capabilities expire according to the service's configured URL
lifetime; the change does not revoke already issued capabilities. It prevents new issuance.
Any future browser attachment feature must introduce explicit authorization and server-side
resource limits before enabling direct uploads.

Verification covers anonymous requests with a valid CSRF token, signed-in issuance attempts,
normal transcript uploads, roster confirmation attachments, and rich-text editor rendering.
