# app/models/config_db.rb
class ConfigDb
  def self.get(name, defaultvalue)
    param = ConfigData.where(config_name: name).pluck(:value).first # Besser als .get(:value)
    param = defaultvalue if param.nil?
    param
  end

  def self.set(name, value)
    # unrestrict_primary_key ist Sequel-spezifisch, nicht ActiveRecord.
    # ActiveRecord handhabt das anders, siehe unten.

    # Finden oder Erstellen des Datensatzes
    record = ConfigData.find_or_initialize_by(config_name: name)
    record.value = value
    record.save
    true
  end
end

