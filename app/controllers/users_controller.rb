class UsersController < ApplicationController

  include RestrictedController
  # PUNDIT_CHECK_FILTERS
  before_filter :changeable_filter,
    :only => [
      :show,
      :edit,
      :update,
      :reset_password
    ]
  before_filter :manager, :only => [:destroy]
  before_filter :manager_or_researcher,
    :only => [
      :index,
      :account_report
    ]
  after_filter :store_location, :only => [:index]

  def changeable_filter
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    @user = User.find(params[:id])
    redirect_home unless @user.changeable?(current_visitor)
  end

  def new
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHECK_AUTHORIZE
    # authorize User
    #This method is called when a user tries to register as a member
    @user = User.new
  end

  def index
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHECK_AUTHORIZE
    # authorize User
    if params[:mine_only]
      @users = User.search(params[:search], params[:page], self.current_visitor)
    # PUNDIT_REVIEW_SCOPE
    # PUNDIT_CHECK_SCOPE (found instance)
    # @users = policy_scope(User)
    else
      @users = User.search(params[:search], params[:page], nil)
    end
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    @user = User.find(params[:id])
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHECK_AUTHORIZE (found instance)
    # authorize @user
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @user }
    end
  end
  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHECK_AUTHORIZE (found instance)
    # authorize @user
    @roles = Role.all
    @projects = Admin::Project.all_sorted
    unless @user.changeable?(current_visitor)
      flash[:warning]  = "You need to be logged in first."
      redirect_to login_url
    end
  end
# GET /users/1/edit
  def preferences
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    @user = User.find(params[:id])
    @roles = Role.all
    @projects = Admin::Project.all_sorted
    unless @user.changeable?(current_visitor)
      flash[:warning]  = "You need to be logged in first."
      redirect_to login_url
    end
  end
   # /users/1/switch
  def switch
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    # @original_user is setup in app/controllers/application_controller.rb
    unless @original_user.has_role?('admin', 'manager')
      redirect_to home_path
    else
      if request.get?
        @user = User.find(params[:id])
        all_users = User.active.all
        all_users.delete(current_visitor)
        all_users.delete(User.anonymous)
        all_users.delete_if { |user| user.has_role?('admin') } unless @original_user.has_role?('admin')

        recent_users = []
        (session[:recently_switched_from_users]  || []).each do |user_id|
          recent_user = all_users.find { |u| u.id == user_id }
          recent_users << all_users.delete(recent_user) if recent_user
        end

        users = all_users.group_by do |u|
          case
          when u.default_user   then :default_users
          when u.portal_student then :student
          when u.portal_teacher then :teacher
          else :regular
          end
        end

        # to avoid nil values, initialize everything to an empty array if it's non-existent
        # users[:student] ||= []
        # users[:regular] ||= []
        # users[:default_users] ||= []
        # users[:student].sort! { |a, b| a.first_name.downcase <=> b.first_name.downcase }
        # users[:regular].sort! { |a, b| a.first_name.downcase <=> b.first_name.downcase }
        [:student, :regular, :default_users, :student, :teacher].each do |ar|
          users[ar] ||= []
          users[ar].sort! { |a, b| a.last_name.downcase <=> b.last_name.downcase }
        end
        @user_list = [
          { :name => 'recent' ,   :users => recent_users     } ,
          { :name => 'guest',     :users => [User.anonymous] } ,
          { :name => 'regular',   :users => users[:regular]  } ,
          { :name => 'students',  :users => users[:student]  } ,
          { :name => 'teachers',  :users => users[:teacher]  }
        ]
        if users[:default_users] && users[:default_users].size > 0
          @user_list.insert(2, { :name => 'default', :users => users[:default_users] })
        end
      elsif request.put?
        if params[:commit] == "Switch"
          if switch_to_user = User.find(params[:user][:id])
            switch_from_user = current_visitor
            original_user_from_session = session[:original_user_id]
            recently_switched_from_users = (session[:recently_switched_from_users] || []).clone
            sign_out self.current_visitor
            sign_in switch_to_user

            # the original user is only set on the session once:
            # the first time an admin switches to another user
            unless original_user_from_session
              session[:original_user_id] = switch_from_user.id
            end
            recently_switched_from_users.insert(0, switch_from_user.id)
            session[:recently_switched_from_users] = recently_switched_from_users.uniq
          end
        end
        redirect_to home_path
      end
    end
  end

  def update
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHECK_AUTHORIZE (did not find instance)
    # authorize @user
    if params[:commit] == "Cancel"
      # FIXME: ugly hack
      # if the Cancel request came from a form generated by
      # the preferences action then redirect to /home
      if request.env["HTTP_REFERER"] =~ /preferences/
        redirect_to :home
      else
        redirect_to users_path
      end
    else
      @user = User.find(params[:id])
      respond_to do |format|
        if @user.update_attributes(params[:user])

          # This update method is shared with admins using users/edit and users using users/preferences.
          # Since the values are checkboxes we can't use the absense of them to denote there are no
          # roles or projects in the form since unchecked checkboxes are not part of the post body.
          # We also can't just rely on the current user role as they may be changing their own preferences
          if current_visitor.has_role?("admin", "manager")
            if params[:user][:has_roles_in_form]
              @user.set_role_ids(params[:user][:role_ids] || [])
            end
            if params[:user][:has_projects_in_form]
              @user.set_project_ids(params[:user][:project_ids] || [])
            end
          end

          # set the cohort tags if we have a teacher
          if @user.portal_teacher && params[:update_cohorts]
            cohorts = params[:cohorts] ? params[:cohorts] : []
            @user.portal_teacher.cohort_list = cohorts
            @user.portal_teacher.save
          end

          flash[:notice] = "User: #{@user.name} was successfully updated."
          format.html do
            if request.env["HTTP_REFERER"] =~ /preferences/
              redirect_to :home
            else
              redirect_to users_path
            end
          end
          format.xml  { head :ok }
        else
          # need the roles and projects instance variables for the edit template
          @roles = Role.all
          @projects = Admin::Project.all_sorted
          format.html { render :action => "edit" }
          format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  def interface
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    # Select the probeware vendor and interface to use when generating jnlps and otml
    # files. This redult is saved in a session variable and if the user is logged-in
    # the selection is also saved into their user record.
    # The result is expressed not only in the jnlp and otml files which are
    # downloaded to the users computer but the vendor_interface id (vid) which is
    # also included in the contruction of the url
    @user = User.find(params[:id])
    if request.xhr?
      render :partial => 'interface', :locals => { :vendor_interface => @user.vendor_interface }
    else
      if !@user.changeable?(current_visitor)
        flash[:warning]  = "You need to be logged in first."
        redirect_to login_url
      else

        if params[:commit] == "Cancel"
          redirect_back_or_default(home_url)
        else
          if request.put?
            respond_to do |format|
              if @user.update_attributes(params[:user])
                format.html {  redirect_back_or_default(home_url) }
                format.xml  { head :ok }
              else
                format.html { render :action => "interface" }
                format.xml  { render :xml => @user.errors.to_xml }
              end
            end
          else
            # @vendor_interface = current_visitor.vendor_interface
            # @vendor_interfaces = Probe::VendorInterface.all.map { |v| [v.name, v.id] }
            # session[:back_to] = request.env["HTTP_REFERER"]
            # render :action => "interface"
          end
        end
      end
    end
  end

  def vendor_interface
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    v_id = params[:vendor_interface]
    if v_id
      @vendor_interface = Probe::VendorInterface.find(v_id)
      render :partial=>'vendor_interface', :layout=>false
    else
      render(:nothing => true)
    end
  end

  def account_report
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    sio = StringIO.new
    rep = Reports::Account.new({:verbose => false})
    rep.run_report(sio)
    send_data(sio.string, :type => "application/vnd.ms.excel", :filename => "accounts-report.xls" )
  end

  def reset_password
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    p = Password.new(:user_id => params[:id])
    p.save(:validate => false) # we don't need the user to have a valid email address...
    session[:return_to] = request.referer
    redirect_to change_password_path(:reset_code => p.reset_code)
  end

  def backdoor
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    sign_out :user
    user = User.find_by_login!(params[:username])
    sign_in user
    head :ok
  end

  #Used for activation of users by a manager/admin
  def confirm
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    if current_visitor && current_visitor.has_role?('admin', 'manager')
      user = User.find(params[:id]) unless params[:id].blank?
      if !params[:id].blank? && user && user.state != "active"
        user.confirm!
        user.make_user_a_member
        # assume this type of user just activated someone from somewhere else in the app
        flash[:notice] = "Activation of #{user.name_and_login} complete."
        redirect_to(session[:return_to] || root_path)
      end
    else
      flash[:notice] = "Please login as an administrator."
      redirect_to(root_path)
    end
  end

  def registration_successful
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize User
    # authorize @user
    # authorize User, :new_or_create?
    # authorize @user, :update_edit_or_destroy?
    if params[:type] == "teacher"
      render :template => 'users/thanks'
    else
      render :template => 'portal/students/signup_success'
    end
  end

end
