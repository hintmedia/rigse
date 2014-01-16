module JnlpHelper
  
  def jnlp_adaptor
    proj = current_project rescue Admin::Project.default_project
    @_jnlp_adaptor ||= JnlpAdaptor.new(proj)
  end
  
  def jnlp_icon_url
    icon_prefix = case APP_CONFIG[:theme]
    when 'itsisu'
      'itsisu_'
    else
      ''
    end
    
    host = root_path(:only_path => false)[0..-2]
    host + path_to_image("#{icon_prefix}jnlp_icon.gif")
  end

  def jnlp_splash_url(learner = nil)
    # throw in a random element to the url so that it'll get requested every time
    opts = { :rand => UUIDTools::UUID.timestamp_create.hexdigest }
    opts[:learner_id] = learner if learner
    return banner_url(opts)
  end

  def resource_jars
    jnlp_adaptor.resource_jars
  end

  def linux_native_jars
    jnlp_adaptor.linux_native_jars
  end

  def macos_native_jars
    jnlp_adaptor.macos_native_jars
  end
  
  def windows_native_jars
    jnlp_adaptor.windows_native_jars
  end

  def pub_interval
    return Admin::Project.pub_interval * 1000
  end

  def system_properties(options={})
    if options[:authoring]
      additional_properties = [
        ['otrunk.view.author', 'true'],
        ['otrunk.view.mode', 'authoring'],
        ['otrunk.remote_save_data', 'true'],
        ['otrunk.rest_enabled', 'true'],
        ['otrunk.remote_url', update_otml_url_for(options[:runnable], false)]
      ]
    elsif options[:learner]
      additional_properties = [
        ['otrunk.view.mode', 'student'],
      ]
      if current_project.use_periodic_bundle_uploading?
        # make sure the periodic bundle logger exists, just in case
        l = options[:learner]
        if l.student.user == current_user
          pbl = l.periodic_bundle_logger || Dataservice::PeriodicBundleLogger.create(:learner_id => l.id)
          additional_properties << ['otrunk.periodic.uploading.enabled', 'true']
          additional_properties << ['otrunk.periodic.uploading.url', dataservice_periodic_bundle_logger_periodic_bundle_contents_url(pbl)]
          additional_properties << ['otrunk.periodic.uploading.interval', pub_interval]
          additional_properties << ['otrunk.session_end.notification.url', dataservice_periodic_bundle_logger_session_end_notification_url(pbl)]
        end
      end
    else
      additional_properties = [
        ['otrunk.view.mode', 'student'],
        ['otrunk.view.no_user', 'true' ],
        ['otrunk.view.user_data_warning', 'true']
      ]
    end
    jnlp_adaptor.system_properties + additional_properties
  end
  
  def jnlp_jar(xml, resource, check_for_main=true)
    if resource[2] && check_for_main
      # TODO: refactor how jar versions (or lack therof) are dealt with
      if resource[1]    # is there a version attribute?
        xml.jar :href => resource[0], :main => true, :version => resource[1]
      else
        xml.jar :href => resource[0], :main => true
      end
    else
      if resource[1]    # is there a version attribute?
        xml.jar :href => resource[0], :version => resource[1]
      else
        xml.jar :href => resource[0]
      end
    end
  end
  
  def jnlp_j2se(xml, jnlp)
    xml.j2se :version => jnlp.j2se_version, 'max-heap-size' => "#{jnlp.max_heap_size}m", 'initial-heap-size' => "#{jnlp.initial_heap_size}m"
  end
  
  def jnlp_os_specific_j2ses(xml, jnlp)
    if jnlp.j2se_version == 'mac_os_x'
      xml.resources {
        xml.j2se :version => jnlp.j2se_version('mac_os_x'), 'max-heap-size' => "#{jnlp.max_heap_size('mac_os_x')}m", 'initial-heap-size' => "#{jnlp.initial_heap_size('mac_os_x')}m"
      }
    end
    if jnlp.j2se_version == 'windows'
      xml.resources {
        xml.j2se :version => jnlp.j2se_version('windows'), 'max-heap-size' => "#{jnlp.max_heap_size('windows')}m", 'initial-heap-size' => "#{jnlp.initial_heap_size('windows')}m"
      }
    end
    if jnlp.j2se_version == 'linux'
      xml.resources {
        xml.j2se :version => jnlp.j2se_version('linux'), 'max-heap-size' => "#{jnlp.max_heap_size('linux')}m", 'initial-heap-size' => "#{jnlp.initial_heap_size('linux')}m"
      }
    end
  end

  def jnlp_resources(xml, options = {})
    # HACKITY HACK to shrink the download size since the pasco-jna jar is 3MB.
    doesnt_need_pasco_usb = current_user.vendor_interface.device_id != 62
    jnlp = jnlp_adaptor.jnlp
    xml.resources {
      jnlp_j2se(xml, jnlp)
      resource_jars.each do |resource|
        next if resource[0] =~ /pasco-jna/ && doesnt_need_pasco_usb
        jnlp_jar(xml, resource)
      end
      system_properties(options).each do |property|
        xml.property(:name => property[0], :value => property[1])
      end
      jnlp_os_specific_j2ses(xml, jnlp)
    }
  end
  
  def jnlp_testing_adaptor
    @_jnlp_testing_adaptor ||= JnlpTestingAdaptor.new
  end
  
  def jnlp_testing_resources(xml, options = {})
    jnlp = jnlp_adaptor.jnlp
    jnlp_for_testing = jnlp_testing_adaptor.jnlp
    xml.resources {
      jnlp_j2se(xml, jnlp)
      resource_jars.each do |resource|
        jnlp_jar(xml, resource, false)
      end
      jnlp_testing_adaptor.resource_jars.each do |resource|
        jnlp_jar(xml, resource)
      end
      system_properties(options).each do |property|
        xml.property(:name => property[0], :value => property[1])
      end
      jnlp_os_specific_j2ses(xml, jnlp)
    }
  end
  
  # There might be issues with filname lengths on IE 6 & 7
  # see http://support.microsoft.com/kb/897168
  def smoosh_file_name(_name,length=28,missing_char="_")
    name = _name.strip.gsub(/[\s+|\/\(\)\:]/,missing_char)
    left_trunc = right_trunc = length/2
    name = "#{name[0,left_trunc]}#{missing_char}#{name[-right_trunc,right_trunc]}"
    return name.strip.gsub(/_+/,missing_char)
  end
  
  def jnlp_headers(runnable)
    content_type = "application/x-java-jnlp-file"
    extension = "jnlp"
    if is_mac_10_9_or_newer
      content_type = "application/vnd.concordconsortium.launcher"
      extension = "ccla"
    end

    response.headers["Content-Type"] = content_type

    # we don't want the jnlp to be cached because it contains session information for the current user
    # if a shared proxy caches it then multiple users will be loading and storing data in the same place
    NoCache.add_headers(response.headers)
    response.headers["Last-Modified"] = runnable.updated_at.httpdate
    filename = smoosh_file_name("#{APP_CONFIG[:site_name]} #{runnable.class.name} #{short_name(runnable.name)}")
    response.headers["Content-Disposition"] = "inline; filename=#{filename}.#{extension}"
  end

  def jnlp_information(xml, learner = nil)
    xml.information { 
      xml.title current_project.name
      xml.vendor "Concord Consortium"
      xml.homepage :href => APP_CONFIG[:site_url]
      xml.description APP_CONFIG[:description]
      xml.icon :href => jnlp_icon_url, :height => "64", :width => "64"
      xml.icon :href => jnlp_splash_url(learner), :kind => "splash"
    }
  end
  
  ########################################
  ## TODO: These jnlp_installer_* methods
  ## should be encapsulated in some class
  ## and track things like jnlp / previous versions &etc.
  ##
  def jnlp_installer_vendor
    "ConcordConsortium"
  end
  
  #
  # convinient
  #
  def load_yaml(filename) 
    file_txt = "---"
    begin
      File.open(filename, "r") do |f|
        file_txt = f.read
      end
    rescue
    end
    return YAML::load(file_txt) || {}
  end
  
  # IMPORTANT: should match <project><name>XXXX</name></project> value
  # from bitrock installer
  def jnlp_installer_project
    config = load_yaml("#{RAILS_ROOT}/config/installer.yml")
    config['shortname'] || "General"
  end
  
  # IMPORTANT: should match <project><version>XXXX</version></project> value
  # from bitrock installer config file: eg: projects/rites/rites.xml
  def jnlp_installer_version
    config = load_yaml("#{RAILS_ROOT}/config/installer.yml")
    config['version'] || "1.0"
  end

  def jnlp_installer_old_versions
    config = load_yaml("#{::Rails.root.to_s}/config/installer.yml")
    config['old_versions'] || []
  end

  def jnlp_installer_not_found_url(os)
    "#{APP_CONFIG[:site_url]}/missing_installer/#{os}"
  end

  def jnlp_resources_linux(xml)
    xml.resources(:os => "Linux") { 
      linux_native_jars.each do |resource|
        xml.nativelib :href => resource[0], :version => resource[1]
      end
    }
  end
  
  def jnlp_mac_java_config(xml)
    jnlp = jnlp_adaptor.jnlp
    # If possible Force Mac OS X to use a 32bit Java 1.5 so that sensors are ensured to work
    # this bit of xml is actually parsed by the binary javaws program on OS X. The way javaws
    # evaulates this xml has changed over time. For example at one point it wasn't using a known arch for
    # which is why there is a non-arch resources element.
    # in recent versions of javaws, at least, I've found that it only does an order of precedence within a single
    # resources element. So for example
    #
    # <resources os="Mac OS X" arch="x86_64">
    #   <j2se version="1.7">
    # </resources>
    # <resources os="Mac OS X" arch="x86_64">
    #   <j2se version="1.6" java-vm-args="-d32">
    # </resources>
    #
    # for some reason it will always pass -d32 to the vm. If instead the xml is:
    #
    # <resources os="Mac OS X" arch="x86_64">
    #   <j2se version="1.7">
    #   <j2se version="1.6" java-vm-args="-d32">
    # </resources>
    #
    # then it will not pass the -d32 option
    xml.resources(:os => "Mac OS X", :arch => "ppc i386") {
      xml.j2se :version => "1.5", :"max-heap-size" => "#{jnlp.max_heap_size}m", :"initial-heap-size" => "32m"
    }
    xml.resources(:os => "Mac OS X", :arch => "x86_64") {
      xml.j2se :version => "1.7", :"max-heap-size" => "#{jnlp.max_heap_size}m", :"initial-heap-size" => "32m"
      xml.j2se :version => "1.5", :"max-heap-size" => "#{jnlp.max_heap_size}m", :"initial-heap-size" => "32m", :"java-vm-args" => "-d32"
    }
    xml.resources(:os => "Mac OS X") {
      xml.j2se :version => "1.7", :"max-heap-size" => "#{jnlp.max_heap_size}m", :"initial-heap-size" => "32m"
      xml.j2se :version => "1.6", :"max-heap-size" => "#{jnlp.max_heap_size}m", :"initial-heap-size" => "32m", :"java-vm-args" => "-d32"
    }
  end

  def jnlp_resources_macosx(xml)
    xml.resources(:os => "Mac OS X") { 
      macos_native_jars.each do |resource|
        xml.nativelib :href => resource[0], :version => resource[1]
      end
    }
  end

  def jnlp_resources_windows(xml)
    xml.resources(:os => "Windows") { 
      windows_native_jars.each do |resource|
        xml.nativelib :href => resource[0], :version => resource[1]
      end
    }
  end

end
