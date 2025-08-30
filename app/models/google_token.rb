class GoogleToken < ApplicationRecord
  belongs_to :user

  def expired?
    expires_at && expires_at < Time.current
  end

  def refresh!
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      refresh_token: self.refresh_token
    )
    
    response = client.refresh!

    update!(
      access_token: client.access_token,
      expires_at: Time.current + client.expires_in
    )
  end
end

