require 'fileutils'
require 'arrayfields'

# use: RAILS_ENV=production ./script/runner "(RinetData.new).run_scheduled_job"
# to run the import of all the RITES districts.
class RinetData
  include RinetCsvFields  # definitions for the fields we use when parsing.
  attr_reader :parsed_data
  attr_accessor :import_logger
  # @@districts = %w{07}
  # @@districts = %w{06 07 16 17 39}
  # @@local_dir = "#{RAILS_ROOT}/rinet_data/districts/csv"
  @@csv_files = %w{students staff courses enrollments staff_assignments staff_sakai student_sakai}

  @@csv_files.each do |csv_file|
    if csv_file =~/_sakai/
      ## 
      ## Create a Caching Hash Map for sakai login info
      ## for the *_sakai csv files  eg student_sakai_map staff_sakai_map
      ##
      eval <<-END_EVAL
        def #{csv_file}_map(key)
          if @#{csv_file}_map
            return @#{csv_file}_map[key]
          end
          @#{csv_file}_map = {}
          # hash_it
          @parsed_data[:#{csv_file}].each do |auth_tokens|
            @#{csv_file}_map[auth_tokens[0]] = auth_tokens[1]
          end
          return @#{csv_file}_map[key]
        end
      END_EVAL
    end
  end
  
  def initialize
    # we probably want to override this later
    @log_filename = "import_log.txt"
    
    # where we startup -- changed when we set district folder
    # log files show up here.
    set_working_directory("/tmp")
    
    @rinet_data_config = YAML.load_file("#{RAILS_ROOT}/config/rinet_data.yml")[RAILS_ENV].symbolize_keys
    @districts = @rinet_data_config[:districts]

    ExternalUserDomain.select_external_domain_by_server_url(@rinet_data_config[:external_domain_url])
    @external_domain_suffix = ExternalUserDomain.external_domain_suffix
    
    @students_hash = {}
    # SASID => Portal::Student
    
    @teachers_hash = {}
    # CertID => Portal::Teacher
    
    @course_hash = {}
    # CourseNumber => course
    @clazz_hash = {}
    # Portal::Clazz.id => {:teachers => [], :students => []}

  end
  
  def local_dir
    "#{RAILS_ROOT}/rinet_data/districts/#{@external_domain_suffix}/csv"
  end
  
  def get_csv_files
    @new_date_time_key = Time.now.strftime("%Y%m%d_%H%M%S")
    Net::SFTP.start(@rinet_data_config[:host], @rinet_data_config[:username] , :password => @rinet_data_config[:password]) do |sftp|
      @districts.each do |district|
        local_district_path = "#{local_dir}/#{district}/#{@new_date_time_key}"
        FileUtils.mkdir_p(local_district_path)
        @@csv_files.each do |csv_file|
          # download a file or directory from the remote host
          remote_path = "#{district}/#{csv_file}.csv"
          local_path = "#{local_district_path}/#{csv_file}.csv"
          @import_logger.info "downloading: #{remote_path} and saving to: \n  #{local_path}"
          sftp.download!(remote_path, local_path)
        end
        current_path = "#{local_dir}/#{district}/current"
        FileUtils.ln_s(local_district_path, current_path, :force => true)
      end
    end
  end

  def parse_csv_files(date_time_key='current')
    if @parsed_data
      @parsed_data # cached data.
    else
      @parsed_data = {}
      @districts.each do |district|
        parse_csv_files_in_dir("#{local_dir}/#{district}/#{date_time_key}",@parsed_data)
      end
    end
    # Data is now available in this format
    # @data['07']['staff'][0][:EmailAddress]
    # lets add login info
    # join_students_sakai
    #  join_staff_sakai
    @parsed_data
  end


  def set_working_directory(path)
    unless @working_directory && @working_directory == path
      if (@import_logger)
        @import_logger.debug("Ended in #{@working_directory} at #{Time.now}")
        @import_logger.debug("..... Next directory is #{path}")
        @import_logger.close
      end
      @working_directory = path
      @import_logger = Logger.new("#{@working_directory}/import_log.txt")
      @import_logger.debug("Started in #{@working_directory} at #{Time.now}")
    end
  end


  def parse_csv_files_in_dir(local_dir_path,existing_data={})
    @parsed_data = existing_data    
    if File.exists?(local_dir_path)
      set_working_directory(local_dir_path)      
      @@csv_files.each do |csv_file|
        local_path = "#{local_dir_path}/#{csv_file}.csv"
        key = csv_file.to_sym
        @parsed_data[key] = []
        File.open(local_path).each do |line|
          add_csv_row(key,line)
        end
      end
    else
      @import_logger.error "no data folder found: #{local_dir_path}"
    end
  end
  
  
  def add_csv_row(key,line)
    # if row.respond_to? fields
    FasterCSV.parse(line) do |row|
      if row.class == Array
        row.fields = FIELD_DEFINITIONS[key]
        @parsed_data[key] << row
      else
        @import_logger.error("couldn't add row data for #{key}: #{line}")
      end
    end
  end
  
  
  
  def join_students_sakai 
    @parsed_data[:students].each do |student|
      @import_logger.debug("working with student  #{student[:Lastname]}")
      found = student_sakai_map(student[:SASID])
      if (found)
        student[:login] = found
      else
        @import_logger.error "student not found in mapping file #{student[:Firstname]} #{student[:Lastname]} (look for #{student[:SASID]} student_sakai.csv )"
      end
    end
  end
  
  def join_staff_sakai
    @parsed_data[:staff].each do |staff_member|
      @import_logger.debug("working with staff_member  #{staff_member[:Lastname]}")
      found = staff_sakai_map(staff_member[:TeacherCertNum])
      if (found)
        staff_member[:login] = found
      else
        @import_logger.error "teacher not found in mapping file #{staff_member[:Firstname]} #{staff_member[:Lastname]} (look for #{staff_member[:TeacherCertNum]} in staff_sakai.csv)"
      end
    end
  end
  
  def school_for(row)
    nces_school = Portal::Nces06School.find(:first, :conditions => {:SEASCH => row[:SchoolNumber]});
    school = nil
    unless nces_school
      @import_logger.warn "could not find school for: #{row[:SchoolNumber]} (have the NCES schools been imported?)"
      @import_logger.info "you might need to run the rake tasks: rake portal:setup:download_nces_data || rake portal:setup:import_nces_from_files"
      # TODO, create one with a special name? Throw exception?
    else
      school = Portal::School.find_or_create_by_nces_school(nces_school)
    end
    school
  end
  
  def district_for(row)
    nces_district = Portal::Nces06District.find(:first, :conditions => {:STID => row[:District]});
    district = nil
    unless nces_district
      @import_logger.warn "could not find distrcit for: #{row[:District]} (have the NCES schools been imported?)"
      @import_logger.info "you might need to run the rake tasks: rake portal:setup:download_nces_data || rake portal:setup:import_nces_from_files"
      # TODO, create one with a special name? Throw exception?
    else
      district = Portal::District.find_or_create_by_nces_district(nces_district)
    end
    district
  end
  

  def create_or_update_user(row)
    # try to cache the data here in memory:
    unless row[:rites_user_id]
      if row[:login]
        if row[:EmailAddress]
          email = row[:EmailAddress].gsub(/\s+/,"").size > 4 ? row[:EmailAddress].gsub(/\s+/,"") : nil
        end
        params = {
          :login  => row[:login],
          :password => row[:Password] || row[:Birthdate],
          :password_confirmation => row[:Password] || row[:Birthdate],
          :first_name => row[:Firstname],
          :last_name  => row[:Lastname],
          :email => email || "#{row[:login]}#{ExternalUserDomain.external_domain_suffix}@mailinator.com" # (temporary unique email address to pass valiadations)
        }
        begin
          user = ExternalUserDomain.find_by_external_login(params[:login])
          if user
            params.delete(:login)
            user.update_attributes!(params)
          else
            user = ExternalUserDomain.create_user_with_external_login!(params)
          end
        rescue
          @import_logger.error("Could not create user because of field-validation errors.")
          return nil
        end
        row[:rites_user_id]=user.id
        user.unsuspend! if user.state == 'suspended'
        unless user.state == 'active'
          user.register!
          user.activate!
        end
        user.roles.clear
      else
        begin
          if(row[:SASID])
            @import_logger.warn("No login found for #{row[:Firstname]} #{row[:Lastname]}, check student_sakai.csv for #{row[:SASID]}")
          elsif(row[:TeacherCertNum])
            @import_logger.warn("No login found for #{row[:Firstname]} #{row[:Lastname]}, check staff_sakai.csv for #{row[:SASID]}")
          else
            throw "no SASID and NO TeacherCertNum for #{row}"
          end
        rescue
          @import_logger.error("could not find user data in #{row}")
        end
      end
    end
    user
  end
  
  def update_teachers
    new_teachers = @parsed_data[:staff]
    new_teachers.each do |teacher| 
      @import_logger.debug("working with teacher #{teacher[:Lastname]}")
      create_or_update_teacher(teacher) 
    end  
  end
  
  def create_or_update_teacher(row)
    # try and cache our data
    teacher = nil
    unless row[:rites_teacher_id]
      user = create_or_update_user(row)
      if (user)
        teacher = Portal::Teacher.find_or_create_by_user_id(user.id)
        teacher.save!
        row[:rites_user_id]=teacher.id
        # how do we find out the teacher grades?
        # teacher.grades << grade_9
    
        # add the teacher to the school
        school = school_for(row)
        if (school)
            school.members << teacher
            school.members.uniq!
        end
        row[:rites_teacher_id] = teacher.id
        if teacher
          @teachers_hash[row[:TeacherCertNum]] = teacher
        end
      end
    else
      @import_logger.debug("teacher with cert: #{row[:TeacherCertNum]} previously created in this import with RITES teacher.id=#{row[:rites_teacher_id]}")
    end
    teacher
  end
  
  def update_students
    new_students = @parsed_data[:students]
    new_students.each do |student| 
      @import_logger.debug("working with student #{student[:Lastname]}")
      create_or_update_student(student)
    end
  end
  
  def create_or_update_student(row)
    student = nil
    unless row[:rites_student_id]
      user = create_or_update_user(row)
      if (user)
        student = user.portal_student
        unless student
          student = Portal::Student.create(:user => user)
          student.save!
          user.portal_student=student;
        end

        # add the student to the school
        school = school_for(row)
        if (school)
            school.members << student
            school.members.uniq!
        end
        row[:rites_student_id] = student.id
        # cache that results in hashtable
        @students_hash[row[:SASID]] = student
      end
    else
      @import_logger.info("student with SASID# #{row[:SASID]} already defined in this import with RITES student.id #{row[:rites_student_id]}")
    end
    row
  end
  
  
  def update_courses
    new_courses = @parsed_data[:courses]
    new_courses.each do |nc| 
      create_or_update_course(nc)
    end
  end
  
  def create_or_update_course(row)
    unless row[:rites_course]
      school = school_for(row);
      courses = Portal::Course.find(:all, :conditions => {:name => row[:Title]}).detect { |course| course.school.id == school.id }
      unless courses
        course = Portal::Course.create!( {:name => row[:Title], :school_id => school_for(row).id })
      else
        # TODO: what if we have multiple matches?
        if courses.class == Array
          @import_logger.warn("Course not unique! #{row[:Title]}, #{school_for(row).id}, found #{courses.size} entries")
          @import_logger.info("returning first found: (#{courses[0]})")
          course = courses[0]
        else
          course = courses
        end
      end
      row[:rites_course] = course
      # cache that results in hashtable
      @course_hash[row[:CourseNumber]] = row[:rites_course]
    else
      @import_logger.info("course #{row[:Title]} already defined in this import for school #{school_for(row).name}")
    end
    row
  end
  
  
  def update_classes
    # from staff assignments:
    @parsed_data[:staff_assignments].each do |nc| 
      create_or_update_class(nc)
    end
    
    # clear students schedules:
    @students_hash.each_value do |student|
      student.clazzes.delete_all
    end
    
    # and re-enroll
    @parsed_data[:enrollments] .each do |nc| 
      create_or_update_class(nc)
    end

  end
  
  def create_or_update_class(row)
    # use course hashmap to find our course
    portal_course = @course_hash[row[:CourseNumber]]
    unless portal_course && portal_course.class == Portal::Course
      @import_logger.error "course not found #{row[:CourseNumber]} nil: #{portal_course.nil?}"
      return
    end
    
    unless row[:StartDate] && row[:StartDate] =~/\d{4}-\d{2}-\d{2}/
      @import_logger.error "bad start time for class: '#{row[:StartDate]}'" unless row =~/\d{4}-\d{2}-\d{2}/
      return
    end
    
    section = row[:CourseSection]
    start_date = DateTime.parse(row[:StartDate]) 
    clazz = Portal::Clazz.find_or_create_by_course_and_section_and_start_date(portal_course,section,start_date)
    
    if row[:SASID] && @students_hash[row[:SASID]]
      student =  @students_hash[row[:SASID]]
      student.clazzes << clazz
      student.save
    elsif row[:TeacherCertNum] && @teachers_hash[row[:TeacherCertNum]]
      clazz.teacher = @teachers_hash[row[:TeacherCertNum]]
      clazz.save
    else
      @import_logger.error("teacher or student not found: SASID: #{row[:SASID]} cert: #{row[:TeacherCertNum]}")
    end
    row
  end
  
  def join_data
    join_students_sakai
    join_staff_sakai
  end
  
  def update_models
    update_teachers
    update_students
    update_courses
    update_classes
  end
  
  def run_importer(district_directory)
    parse_csv_files_in_dir(district_directory)
    join_data
    update_models
  end
  
  def run_scheduled_job
    get_csv_files
    parse_csv_files
    join_data
    update_models
  end
  
end