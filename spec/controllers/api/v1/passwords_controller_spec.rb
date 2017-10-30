require 'spec_helper'

describe API::V1::PasswordsController do

    let(:user1) { Factory.create(   :user,
                                    :login => 'testuser',
                                    :email => 'foo@foo.com' ) }

    describe "POST to reset_password" do

        before(:each) do
            sign_out :user
        end

        context "with valid email" do
            it "returns success" do
                post :reset_password, { :login_or_email => user1.email }
                expect(response.status).to eq(200)
                body = JSON.parse(response.body)
                expect(body['message']).to eq('A link to change your password has been sent to foo@foo.com.')
            end
        end

        context "with valid login" do
            it "returns success" do
                post :reset_password, { :login_or_email => user1.login }
                expect(response.status).to eq(200)
                body = JSON.parse(response.body)
                expect(body['message']).to eq('A link to change your password has been sent to foo@foo.com.')
            end
        end

        context "with invalid login" do
            it "returns failure" do
                post :reset_password, { :login_or_email => "invalid_login_" }
                expect(response.status).to eq(403)
                body = JSON.parse(response.body)
                expect(body['message']).to eq('Cannot find user or email.')
            end
        end

        context "with SSO email" do
            it "returns failure" do

                sso_user = Factory.create(:user,
                                    :login => 'ssouser',
                                    :email => 'foo@gmail.com')

                sso_user.authentications.create(
                                    :provider => 'Google',
                                    :uid => 'foo_uid' )

                post :reset_password, { :login_or_email => sso_user.email }
                expect(response.status).to eq(403)
                body = JSON.parse(response.body)
                expect(body['reason']).to eq('external_auth_user')
            end
        end

    end

end
