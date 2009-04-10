class Itsi::User < Itsi::Itsi
  set_table_name "itsidiy_users"

  self.extend SearchableModel

  @@searchable_attributes = %w{login email first_name last_name}
  class <<self
    def searchable_attributes
      @@searchable_attributes
    end
  end

  belongs_to :vendor_interface, :class_name => 'VendorInterface'

  has_many :activities, :class_name => "Itsi::Activity", :order => 'name'
  has_many :models, :class_name => "Itsi::Model"
  has_many :model_types, :class_name => "Itsi::ModelTypes"

  def name
    "#{first_name} #{last_name}"
  end

end
