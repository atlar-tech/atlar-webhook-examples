# frozen_string_literal: true

require 'sinatra'
require 'openssl'
require 'base64'

post '/' do
  signature = request.env['HTTP_WEBHOOK_SIGNATURE']
  timestamp = request.env['HTTP_WEBHOOK_REQUEST_TIMESTAMP']
  halt 400 if !signature || !timestamp
  unless verify_webhook_signature(signature, timestamp, request.body, ENV['WEBHOOK_B64KEY'],
                                  ENV['MAX_REQUEST_AGE_SECONDS'].to_i || 500)
    halt 401
  end
end

def verify_webhook_signature(signatures, timestamp, payload, base64_key, max_age_seconds)
  begin
    age_seconds = Time.now - Time.parse(timestamp)
  rescue StandardError
    return false
  end
  return false if age_seconds > max_age_seconds

  key = Base64.decode64(base64_key)
  calculated_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), key, "#{payload.string}.#{timestamp}")
  signatures.split(',').each do |signature|
    return true if Rack::Utils.secure_compare(calculated_signature, signature)
  end
  false
end

configure do
  set :bind, '0.0.0.0'
  set :port, ENV['PORT']
end
