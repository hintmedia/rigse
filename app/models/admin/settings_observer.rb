class Admin::SettingsObserver < ActiveRecord::Observer
  def before_update(settings)
    if settings.custom_css_changed?
      # this file is created by caching a specific route
      # match '/stylesheets/settings.css' => 'home#settings_css', :as => :settings_css
      css_path = "#{ActionController::Base.page_cache_directory}/stylesheets/settings.css"
      File.delete(css_path) if File.exists?(css_path)
    end
    if settings.use_bitmap_snapshots_changed?
      investigations_path = File.join(ActionController::Base.page_cache_directory, "investigations")
      cached_files = File.join(investigations_path,"*.otml")
      Dir.glob(cached_files).each do |otml_file|
        File.delete(otml_file) if File.exists?(otml_file)
      end
    end
  end
end
