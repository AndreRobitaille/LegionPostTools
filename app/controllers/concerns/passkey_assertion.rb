module PasskeyAssertion
  private

  def verify_passkey_assertion!(credential, stored, challenge)
    credential.verify(challenge, public_key: stored.public_key, sign_count: stored.sign_count, user_verification: true)
    stored.update!(sign_count: credential.sign_count, last_used_at: Time.current)
  end

  def public_key_credential_params
    params.require(:publicKeyCredential).permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      response: %i[
        attestationObject
        authenticatorData
        clientDataJSON
        signature
        userHandle
      ],
      clientExtensionResults: {}
    ).to_h
  end
end
