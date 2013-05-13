require File.expand_path('../../spec_helper', __FILE__)

describe ExternalActivity do
  let(:valid_attributes) { {
      :user_id => 1,
      :uuid => "value for uuid",
      :name => "value for name",
      :description => "value for description",
      :publication_status => "value for publication_status",
      :is_exemplar => true,
      :url => "http://www.concord.org/"
    } }

  it "should create a new instance given valid attributes" do
    ExternalActivity.create!(valid_attributes)
  end

  describe '#search_list' do
    let (:exemplar) do
      ea = ExternalActivity.create!(valid_attributes)
      ea.publication_status = 'published'
      ea.save
      ea
    end
    let (:community) do
      ea = ExternalActivity.create!(valid_attributes)
      ea.is_exemplar = false
      ea.publication_status = 'published'
      ea.save
      ea
    end

    context 'when include_community is true' do
      let (:params) { { :include_community => true } }
      before(:each) do
        exemplar
        community
      end

      it 'should return activities where is_exemplar is true or false' do
        external = ExternalActivity.search_list(params)
        external.should include(exemplar, community)
      end
    end

    context 'when include_community is false or absent' do
      let (:params) { { } }
      before(:each) do
        exemplar
      end

      it 'should return only activities where is_exemplar is true' do
        external = ExternalActivity.search_list(params)
        external.should include(exemplar)
      end
    end
  end

  describe "url transforms" do
    let(:act) { ExternalActivity.create!(valid_attributes)}
    let(:learner) { mock_model(Portal::Learner, :id => 34) }

    it "should default to not appending the learner id to the url" do
      act.append_learner_id_to_url.should be_false
    end

    it "should return the original url when appending is false" do
      act.url.should eql(valid_attributes[:url])
      act.url(learner).should eql(valid_attributes[:url])
    end

    it "should return a modified url when appending is true" do
      act.append_learner_id_to_url = true
      act.url.should eql(valid_attributes[:url])
      act.url(learner).should eql(valid_attributes[:url] + "?learner=34")
    end

    it "should return a correct url when appending to a url with existing params" do
      url = "http://www.concord.org/?foo=bar"
      act.append_learner_id_to_url = true
      act.url = url
      act.url(learner).should eql(url + "&learner=34")
    end

    it "should return a correct url when appending to a url with existing fragment" do
      url = "http://www.concord.org/#3"
      act.append_learner_id_to_url = true
      act.url = url
      act.url(learner).should eql(url + "?learner=34")
    end
  end
end
