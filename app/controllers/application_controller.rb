class ApplicationController < ActionController::Base
  
  include Pundit::Authorization
  include Pagy::Backend

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to request.referer || root_path, alert: exception.message
  end
end
