class DataCollector < ActiveRecord::Base
  belongs_to :user
  belongs_to :probe_type

  has_many :page_elements, :as => :embeddable
  has_many :pages, :through =>:page_elements
  has_many :teacher_notes, :as => :authored_entity
  acts_as_replicatable
  
  include Changeable
  
  self.extend SearchableModel
  
  @@searchable_attributes = %w{uuid name description title x_axis_label x_axis_units y_axis_label y_axis_units}
  
  class <<self
    def searchable_attributes
      @@searchable_attributes
    end
  end

  def probe_type=(probe_type)
    self.probe_type_id = probe_type.id
    self.title = "#{probe_type.name} Data Collector"
    self.name = self.title
    self.y_axis_label = probe_type.name
    self.y_axis_units = probe_type.unit
    self.y_axis_min = probe_type.min
    self.y_axis_max = probe_type.max
    # self.x_axis_label
    # self.x_axis_units
    # self.x_axis_min
    # self.x_axis_max
  end

  def y_axis_title
    "#{self.y_axis_label} (#{self.y_axis_units})"
  end

  def x_axis_title
    "#{self.x_axis_label} (#{self.x_axis_units})"
  end

  DISTANCE_PROBE_TYPE = ProbeType.find_by_name('Distance')
  
  default_value_for :name, "Data Graph"
  default_value_for :description, "Data Collector Graphs can be used for sensor data or predictions."

  default_value_for :y_axis_label, "Distance"
  
  default_values :x_axis_min                  =>  0,
                 :x_axis_max                  =>  30,
                 :x_axis_label                =>  "Time",
                 :x_axis_units                =>  "s",
                 :multiple_graphable_enabled  =>  false,
                 :draw_marks                  =>  false,
                 :connect_points              =>  true,
                 :autoscale_enabled           =>  false,
                 :ruler_enabled               =>  false,
                 :show_tare                   =>  false,
                 :single_value                =>  false


  default_value_for :probe_type, DISTANCE_PROBE_TYPE

  def self.display_name
    "Graph"
  end
end
