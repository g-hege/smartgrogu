class GoogleAuthController < ApplicationController
  def authorize
    
    client = Signet::OAuth2::Client.new({
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      scope: [
        'https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/gmail.send'
      ],
      redirect_uri: ENV['GOOGLE_REDIRECT_URI'],
      access_type: 'offline',
      prompt: 'consent'
    })

    redirect_to client.authorization_uri.to_s, allow_other_host: true
  end

  def callback
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      redirect_uri: ENV['GOOGLE_REDIRECT_URI'],
      code: params[:code]
    )

    response = client.fetch_access_token!

    session[:access_token] = response['access_token']
    session[:refresh_token] = response['refresh_token']

    tokens = {
      access_token: response['access_token'],
      refresh_token: response['refresh_token'],
      expires_at: Time.now.to_i + response['expires_in'].to_i
    }

    GoogleTokenStore.save(tokens)

    redirect_to root_path, notice: 'Google verbunden!'

  end
end
