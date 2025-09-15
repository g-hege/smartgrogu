class Avo::ToolsController < Avo::ApplicationController
  def dashboard
    @page_title = "Energy Dashboard"
    add_breadcrumb "Energy Dashboard"
  end
end
