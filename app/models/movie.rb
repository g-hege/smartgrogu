class Movie < ApplicationRecord
	 self.table_name = "movie"
	 self.inheritance_column = nil
end
