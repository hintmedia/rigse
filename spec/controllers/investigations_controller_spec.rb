require File.expand_path('../../spec_helper', __FILE__)#include ApplicationHelper

describe InvestigationsController do
  before(:each) do
    @current_settings = mock(
      :name => "test settings",
      :using_custom_css? => false,
      :use_student_security_questions => false,
      :use_bitmap_snapshots? => false,
      :require_user_consent? => false,
      :default_cohort => nil)
    Admin::Settings.stub!(:default_settings).and_return(@current_settings)
    controller.stub(:before_render) {
      response.template.stub(:net_logo_package_name).and_return("blah")
      response.template.stub_chain(:current_settings).and_return(@current_settings);
    }

    @admin_user = Factory.create(:user, { :email => "test@test.com", :password => "password", :password_confirmation => "password" })
    @admin_user.add_role("admin")

    login_admin

    @investigation = Factory.create(:investigation, {
      :name => "test investigation",
      :description => "new decription",
      :publication_status => "published"
    })
  end

  describe '#index' do
    it "should redirect to search page with investigations filter checked" do
      get :index
      expect(response).to redirect_to search_url(material_types: Search::InvestigationMaterial)
    end
  end

  describe '#duplicate' do
    it "should handle the duplicate method without error" do
      get :duplicate, :id => @investigation.id
    end
  end

  describe "#show" do
    it "should handle the show method without error" do
      get :show, :id => @investigation.id
    end

    describe "with teacher mode='true'" do
      before(:each) do
        controller.stub!(:render)
        get :show, :id => @investigation.id, :teacher_mode => "true"
      end
      it "should assign true to teacher_mode instance var" do
        assert(assigns(:teacher_mode) == true)
      end
    end
    describe "with teacher mode='false'" do
      before(:each) do
        controller.stub!(:render)
        get :show, :id => @investigation.id, :teacher_mode => "false"
      end
      it "should assign false to teacher_mode instance var" do
        assert(assigns(:teacher_mode) == false)
      end
    end
  end
end
