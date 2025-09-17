class Avo::ToolsController < Avo::ApplicationController
  def temperature_dashboard
    @page_title = "Temperature dashboard"
    add_breadcrumb "Temperature dashboard"
  end
  def dashboard
    @page_title = "Energy Dashboard"
    add_breadcrumb "Energy Dashboard"
  end

end
