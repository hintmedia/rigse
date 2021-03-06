require File.expand_path('../../../spec_helper', __FILE__)

describe Portal::LearnersController do

  describe "GET config" do
    before(:each) do
      @controller.stub!(:current_settings).and_return(
        mock(:settings,
          :use_periodic_bundle_uploading? => false,
          :use_student_security_questions => false,
          :require_user_consent? => false)
      )
      @learner = Factory(:full_portal_learner)
    end

    it "should render the config builder" do
      sign_in @learner.student.user
      get :show, :format => :config, :id => @learner.id
    end


    it "should raise an exception when unauthorized config request is made" do
      lambda {
        get :show, :format => :config, :id => @learner.id
      }.should raise_error
    end

    it "should log in the user with the jnlp_session" do
      @learner.student.user.confirm!
      Dataservice::JnlpSession.stub!(:get_user_from_token).and_return(
        @learner.student.user
      )
      get :show, :format => :config, :id => @learner.id, :jnlp_session => "doesn't mater what is here"
      @controller.current_user.should == @learner.student.user
    end

    it "should work even if a different user is currently logged in" do
      other_user = Factory(:confirmed_user)
      other_user.confirm!
      sign_in other_user

      @learner.student.user.confirm!
      Dataservice::JnlpSession.stub!(:get_user_from_token).and_return(
        @learner.student.user
      )
      get :show, :format => :config, :id => @learner.id, :jnlp_session => "doesn't mater what is here"
      @controller.current_user.should == @learner.student.user
    end
  end

  describe "GET report" do
    let(:physics_investigation) { Factory.create(
        :investigation,
        :name => 'physics_inv',
        :publication_status => 'published') }

    let(:offering) { Factory.create(
        :portal_offering,
        runnable_id: physics_investigation.id,
        runnable_type: 'Activity',
        clazz: clazz)}

    let(:clazz)       { Factory.create :portal_clazz, teachers: [teacher] }
    let(:student_id)  { 7 }
    let(:learner_stubs) {{
        student_id: student_id,
        offering_id: offering.id,
        offering: offering
    }}
    let(:learner)     { mock_model(Portal::Learner, learner_stubs)}
    let(:post_params) { {id: learner.id }      }
    let(:teacher)     { Factory.create :teacher }
    let(:teacher_b)   { Factory.create :teacher }

    before(:each) do
      sign_in user
      Portal::Learner.stub(:find).and_return(learner)
    end

    describe "When the teacher of the class requests the report" do
      let(:user)           { teacher.user }
      let(:report_url)     { "https://concord-consortium.github.io/portal-report/" }
      let(:report_domains) { "concord-consortium.github.io" }
      before(:each) do
        ENV.stub(:[]).and_return('')
        ENV.stub(:[]).with("REPORT_VIEW_URL").and_return(report_url)
        ENV.stub(:[]).with("REPORT_DOMAINS").and_return(report_domains)
      end

      it "should redirect to the external reporting service as configured by the environment" do
        get :report, post_params
        response.location.should =~ /#{report_url}/
      end
      it "should include an authentication token parameter" do
        get :report, post_params
        response.location.should =~ /token=([0-9]|[a-f]){32}/
      end
      it "should include the student_ids parameter" do
        get :report, post_params
        response.location.should =~ /student_ids/
      end
    end

    describe "when the current user is a teacher without access to this offering" do
      let(:user) { teacher_b.user }
      it "should redirect the user to /recent_activity" do
        get :report, post_params
        response.should redirect_to :recent_activity
      end
    end
  end

end
