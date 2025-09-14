class Avo::Dashboards::Dashy < Avo::Dashboards::BaseDashboard
  self.id = "dashy"
  self.name = "Dashy"
   self.description = "Tiny dashboard description"
   self.grid_cols = 3
   self.visible = -> do
     true
   end

  def cards
    # cards go here
    # card UsersCount
  end
end
