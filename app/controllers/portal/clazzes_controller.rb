class Portal::ClazzesController < ApplicationController
  
  # TODO:  There need to be a lot more 
  # controller filters here...
  # this only protects management actions:
  include RestrictedPortalController
  
  CANNOT_REMOVE_LAST_TEACHER = "Sorry, you can't remove the last teacher from a class. Please add another teacher before attempting to remove any."
  ERROR_UNAUTHORIZED = "You are not authorized to perform the requested operation."
  
  public
  # GET /portal_clazzes
  # GET /portal_clazzes.xml
  def index
    @portal_clazzes = Portal::Clazz.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @portal_clazzes }
    end
  end

  # GET /portal_clazzes/1
  # GET /portal_clazzes/1.xml
  def show
    @portal_clazz = Portal::Clazz.find(params[:id], :include =>  [:teachers, { :offerings => [:learners, :open_responses, :multiple_choices] }])
    @portal_clazz.refresh_saveable_response_objects
    @teacher = @portal_clazz.parent
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @portal_clazz }
    end
  end

  # GET /portal_clazzes/new
  # GET /portal_clazzes/new.xml
  def new
    @semesters = Portal::Semester.find(:all)
    @portal_clazz = Portal::Clazz.new
    if params[:teacher_id]
      @portal_clazz.teacher = Portal::Teacher.find(params[:teacher_id])
    elsif current_user.portal_teacher
      @portal_clazz.teacher = current_user.portal_teacher
      @portal_clazz.teacher_id = current_user.portal_teacher.id
    end
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @portal_clazz }
    end
  end

  # GET /portal_clazzes/1/edit
  def edit
    @portal_clazz = Portal::Clazz.find(params[:id])
    @semesters = Portal::Semester.find(:all)
    if request.xhr?
      render :partial => 'remote_form', :locals => { :portal_clazz => @portal_clazz }
    end
  end

  # POST /portal_clazzes
  # POST /portal_clazzes.xml
  def create
    @semesters = Portal::Semester.find(:all)
    
    @object_params = params[:portal_clazz]
    school_id = @object_params.delete(:school)
    @portal_clazz = Portal::Clazz.new(@object_params)
    
    okToCreate = true
    if !school_id
      # This should never happen, since the schools dropdown should consist of the default site school if the current user has no schools
      flash[:error] = "You need to belong to a school in order to create classes. Please join a school and try again."
      okToCreate = false
    end
    
    if okToCreate && !@portal_clazz.teacher
      if current_user.anonymous?
        flash[:error] = "Anonymous can't create classes. Please log in and try again."
        okToCreate = false
      elsif current_user.portal_teacher
        @portal_clazz.teacher_id = current_user.portal_teacher.id
        @portal_clazz.teacher = current_user.portal_teacher
      else
        teacher = Portal::Teacher.create(:user => current_user) # Former call set :user_id directly; class validations didn't like that
        if teacher && teacher.id # Former call used .id directly on create method, leaving room for NilClass error
          @portal_clazz.teacher_id = teacher.id # Former call tried to do another Portal::Teacher.create. We don't want to double-create this teacher
          @portal_clazz.teacher = teacher
          @portal_clazz.teacher.schools << Portal::School.find_by_name(APP_CONFIG[:site_school])
        else
          flash[:error] = "There was an error trying to associate you with this class. Please try again."
          okToCreate = false
        end
      end
    end
    
    if okToCreate
      # We can't use Course.find_or_create_by_course_number_name_and_school_id here, because we don't know what course_number we're looking for
      course = Portal::Course.find_by_name_and_school_id(@portal_clazz.name, school_id)
      course = Portal::Course.create({
        :name => @portal_clazz.name,
        :course_number => nil,
        :school_id => school_id
      }) if course.nil?
      
      if course
        # This will finally tie this clazz to a course and a school
        @portal_clazz.course = course
      else
        flash[:error] = "There was an error trying to create your new class. Please try again."
        okToCreate = false
      end
    end
    
    respond_to do |format|
      if okToCreate && @portal_clazz.save
        flash[:notice] = 'Portal::Clazz was successfully created.'
        format.html { redirect_to(@portal_clazz) }
        format.xml  { render :xml => @portal_clazz, :status => :created, :location => @portal_clazz }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @portal_clazz.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /portal_clazzes/1
  # PUT /portal_clazzes/1.xml
  def update
    @semesters = Portal::Semester.find(:all)
    @portal_clazz = Portal::Clazz.find(params[:id])
    if request.xhr?
      @portal_clazz.update_attributes(params[:portal_clazz])
      render :partial => 'show', :locals => { :portal_clazz => @portal_clazz }
    else
      respond_to do |format|
        if @portal_clazz.update_attributes(params[:portal_portal_clazz])
          flash[:notice] = 'Portal::Clazz was successfully updated.'
          format.html { redirect_to(@portal_clazz) }
          format.xml  { head :ok }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @portal_clazz.errors, :status => :unprocessable_entity }
        end
      end
    end
  end  

  # DELETE /portal_clazzes/1
  # DELETE /portal_clazzes/1.xml
  def destroy
    @portal_clazz = Portal::Clazz.find(params[:id])
    @portal_clazz.destroy
    respond_to do |format|
      format.html { redirect_to(portal_clazzes_url) }
      format.js
      format.xml  { head :ok }
    end
  end
  
  ## END OF CRUD METHODS
  def edit_offerings
    @portal_clazz = Portal::Clazz.find(params[:id])
    @grade_span = session[:grade_span] ||= cookies[:grade_span]
    @domain_id = session[:domain_id] ||= cookies[:domain_id]
  end
  
  # HACK:
  # TODO: (IMPORTANT:) This  method is currenlty only for ajax requests, and uses dom_ids 
  # TODO: to infer runnables. Rewrite this, so that the params are less JS/DOM specific..
  def add_offering
    @portal_clazz = Portal::Clazz.find(params[:id])
    dom_id = params[:dragged_dom_id]
    container = params[:dropped_dom_id]
    runnable_id = params[:runnable_id]
    unless params[:runnable_type] == 'portal_offering'
      runnable_type = params[:runnable_type].classify
      @offering = Portal::Offering.find_or_create_by_clazz_id_and_runnable_type_and_runnable_id(@portal_clazz.id,runnable_type,runnable_id)
      if @offering
        @offering.save
        @portal_clazz.reload
      end
      render :update do |page|
        page << "var element = $('#{dom_id}');"
        page << "element.remove();"
        page.insert_html :top, container, :partial => 'shared/offering_for_teacher', :locals => {:offering => @offering}
      end
    end
    @offering.refresh_saveable_response_objects
  end
  
  
  # HACK:
  # TODO: (IMPORTANT:) This  method is currenlty only for ajax requests, and uses dom_ids 
  # TODO: to infer runnables. Rewrite this, so that the params are less JS/DOM specific..
  def remove_offering
    @portal_clazz = Portal::Clazz.find(params[:id])
    dom_id = params[:dragged_dom_id]
    container = params[:dropped_dom_id]
    offering_id = params[:offering_id]
    @offering = Portal::Offering.find(offering_id)
    if @offering
      @runnable = @offering.runnable
      @offering.destroy
      @portal_clazz.reload
    end
    render :update do |page|
      page << "var container = $('#{container}');"
      page << "var element = $('#{dom_id}');"
      page << "element.remove();"
      page.insert_html :top, container, :partial => 'shared/runnable', :locals => {:runnable => @runnable}
    end  
  end
  
  # HACK: Add a student to a clazz
  # TODO: test this method
  def add_student
    @student = nil
    @portal_clazz = Portal::Clazz.find(params[:id])

    if params[:student_id] && (!params[:student_id].empty?)
      @student = Portal::Student.find(params[:student_id])
    end
    if @student
      @student.add_clazz(@portal_clazz)
      @portal_clazz.reload
      render :update do |page|
        page.replace_html  'students_listing', :partial => 'portal/students/table_for_clazz', :locals => {:portal_clazz => @portal_clazz}
        page.visual_effect :highlight, 'students_listing'
      end
    else
      render :update do |page|
        page << "$('flash').update('that was a total failure')"
      end
    end
  end
  
  def add_teacher
    @portal_clazz = Portal::Clazz.find_by_id(params[:id])
    
    (render(:update) { |page| page << "$('flash').update('Class not found')" } and return) unless @portal_clazz
    (render(:update) { |page| page << "$('flash').update('#{ERROR_UNAUTHORIZED}')" } and return) unless current_user && @portal_clazz.changeable?(current_user)
    
    @teacher = Portal::Teacher.find_by_id(params[:teacher_id])
    
    (render(:update) { |page| page << "$('flash').update('Teacher not found')" } and return) unless @teacher
    
    begin
      @teacher.add_clazz(@portal_clazz)
      @portal_clazz.reload
      render :update do |page|
        page.replace_html  'teachers_listing', :partial => 'portal/teachers/table_for_clazz', :locals => {:portal_clazz => @portal_clazz}
        page.visual_effect :highlight, 'teachers_listing'
      end
    rescue
      render :update do |page|
        page << "$('flash').update('There was an error while processing your request.')"
      end
    end
  end
  
  def remove_teacher
    @portal_clazz = Portal::Clazz.find_by_id(params[:id])
    
    (render(:update) { |page| page << "$('flash').update('Class not found')" } and return) unless @portal_clazz
    (render(:update) { |page| page << "$('flash').update('#{ERROR_UNAUTHORIZED}')" } and return) unless current_user && @portal_clazz.changeable?(current_user)
    
    @teacher = @portal_clazz.teachers.find_by_id(params[:teacher_id])

    (render(:update) { |page| page << "$('flash').update('Teacher not found')" } and return) unless @teacher
    (render(:update) { |page| page << "$('flash').update('#{CANNOT_REMOVE_LAST_TEACHER}')" } and return) unless @portal_clazz.teachers.length > 1

    begin
      @teacher.remove_clazz(@portal_clazz)
      @portal_clazz.reload
      
      if @portal_clazz.teachers.size < 2
        # You aren't allowed to remove the last teacher. Redraw the entire table, to disable the last delete link. -- Cantina-CMH 06/09/10
        render :update do |page|
          page.replace_html  'teachers_listing', :partial => 'portal/teachers/table_for_clazz', :locals => {:portal_clazz => @portal_clazz}
        end
      else
        respond_to do |format|
          format.js
        end
      end
    rescue
      render :update do |page|
        page << "$('flash').update('There was an error while processing your request.')"
      end
    end
  end
    
end
