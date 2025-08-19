class Crypto < ApplicationRecord
  self.table_name = "crypto"
  def self.timestamps
    false
  end
end
