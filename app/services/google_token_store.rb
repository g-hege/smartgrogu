# /lib/google_token_store.rb
require 'json'

class GoogleTokenStore
  TOKEN_FILE = Rails.root.join("config", "google_tokens.json")

  def self.save(tokens)
    File.write(TOKEN_FILE, JSON.pretty_generate(tokens))
  end

  def self.load
    return nil unless File.exist?(TOKEN_FILE)

    data = JSON.parse(File.read(TOKEN_FILE))
    data.transform_keys(&:to_sym)
  end
end
