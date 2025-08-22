require 'cgi'

class CallMeBot
	def self.signal_send(msg)
		# URL-encode den Nachrichtentext, bevor du ihn verwendest
		encoded_msg = CGI.escape(msg)
		
		# Verwende den kodierten Text in der URL
		response = HTTParty.get("#{Rails.application.credentials.callmebot}#{encoded_msg}")
		response.include?('Message sent to') ? true : false
	end
end