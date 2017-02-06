Feature: An author registers to use the portal

  As a potential author
  I want to register
  In order to author content on the portal

  Background:
    Given The default settings and jnlp resources exist using factories
    And the database has been seeded
    And member registration is enabled


  Scenario: Anonymous user signs up as an author
    Given I am an anonymous user
    When I go to the pick signup page
    And I press "Sign up as a member"
    Then I should see "Signup"
    When I fill in the following:
      | user_first_name            | Example             |
      | user_last_name             | Author              |
      | user_email                 | example@example.com |
      | user_login                 | login               |
      | user_password              | password            |
      | user_password_confirmation | password            |

    And I press "Sign up"
    Then I should see "A message with a confirmation link has been sent to your email address. Please open the link to activate your account."
    And "example@example.com" should receive an email
    When I open the email
    Then I should see "Please activate your new account" in the email subject
    When I follow "/confirmation" in the email
    Then I should see "Your account was successfully confirmed. You are now signed in."
    And I should not see "Sorry, there was an error creating your account"

  Scenario: Anonymous user signs up as an author with form errors
    Given I am an anonymous user
    When I go to the pick signup page
    And I press "Sign up as a member"
    Then I should see "Signup"
    When I press "Sign up"
    Then I should see "9 errors prohibited this user from being saved"
    When I fill in the following:
      | user_first_name            | Example             |
      | user_last_name             | Author              |
      | user_email                 | example@example.com |
      | user_login                 | login               |
      | user_password              | password            |
      | user_password_confirmation | password            |

    And I press "Sign up"
    Then I should see "A message with a confirmation link has been sent to your email address. Please open the link to activate your account."
    And "example@example.com" should receive an email
    When I open the email
    Then I should see "Please activate your new account" in the email subject
    When I follow "/confirmation" in the email
    Then I should see "Your account was successfully confirmed. You are now signed in."
    And I should not see "Sorry, there was an error creating your account"

  Scenario: Anonymous user can't sign up as an author when member registration is disabled
    Given I am an anonymous user
    And member registration is disabled
    When I go to the pick signup page
    Then I should not see the button "Sign up as a member"
