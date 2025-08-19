class CallMeBot
	def self.signal_send(msg)
		response = HTTParty.get("#{Rails.application.credentials.callmebot}#{msg}")
	end
end