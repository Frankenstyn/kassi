module AsismsHelper
  require 'json'
  require 'rest_client'
  
  def self.send(message, number)
    if number.nil?
      return false
    end
    
    sms_uri = APP_CONFIG.asi_url+'/sms'
    sms_params = {}
    sms_params[:number] = number
    sms_params[:text] = message
    begin
      json = RestClient.post(sms_uri, sms_params,{ :cookies => Session.kassi_cookie })
      response = JSON.parse(json)
      if response.response.code != 200
        ApplicationHelper.send_error_notification("Sms send failed, message: #{response.response.message}", "SMS error", sms_params)
        return false
      end
      return true
    rescue Exception => e
      ApplicationHelper.send_error_notification("Sms send failed, message: #{e.message}", "SMS error", sms_params)
      return false
    end
  end
  
end
