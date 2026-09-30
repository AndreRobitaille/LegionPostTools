module MinutesDraftProviders
  Result = Data.define(
    :data,
    :provider_response_id,
    :provider_request_id,
    :model,
    :input_tokens,
    :output_tokens,
    :reasoning_tokens,
    :total_tokens
  )
end
