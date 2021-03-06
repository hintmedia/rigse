Feature: Student joins another class

  In order to be part of a class
  As a student
  I want to join the class after I have already registered

  Background:
    Given The default settings and jnlp resources exist using factories
    And the database has been seeded

  @javascript
  Scenario: Student joins another class
    And the class "My Class" has the class word "word"
    And the student "student" belongs to class "Class_with_no_students"
    And I am logged in with the username student
    And I am on my classes page
    And I fill in "clazz_class_word" with "word"
    And I press "Submit"
    And I wait 1 second
    Then I should see "John Nash"
    When I press "Join"
    Then I should see "Successfully registered for class."
    And the student "student" should belong to the class "My Class"

  @javascript
  Scenario: Student joins another class with invalid information
    Given the option to allow default classes is enabled
    And the class "My Class" has the class word "word"
    And the student "student" belongs to class "Class_with_no_students"
    And I am logged in with the username student
    And I am on my classes page
    And I press "Submit"
    Then I should see "Please enter a valid class word and try again."
    When I fill in "clazz_class_word" with "word"
    And I press "Submit"
    And I wait 1 second
    Then I should see "John Nash"
    And I should not see "Please enter a valid class word and try again."
    When I press "Join"
    Then I should see "Successfully registered for class."
    And the student "student" should belong to the class "My Class"

  @javascript
  Scenario: With the default class enabled, student joins another class
    Given the option to allow default classes is enabled
    And the class "My Class" has the class word "word"
    And the student "student" belongs to class "Class_with_no_students"
    And I am logged in with the username student
    And I am on my classes page
    And I fill in "clazz_class_word" with "word"
    And I press "Submit"
    And I wait 1 second
    Then I should see "By joining this class, the teacher John Nash will be able to see all of your current and future work. If do not want to share your work, but do want to join the class please create a second account and use it to join the class"
    And I should see "Click 'Join' to continue registering for this class."
    When I press "Join"
    Then I should see "Successfully registered for class."
    And the student "student" should belong to the class "My Class"

  @javascript
  Scenario: With the default class enabled, student joins another class with invalid information
    Given the option to allow default classes is enabled
    And the class "My Class" has the class word "word"
    And the student "student" belongs to class "Class_with_no_students"
    And I am logged in with the username student
    And I am on my classes page
    And I press "Submit"
    Then I should see "Please enter a valid class word and try again."
    When I fill in "clazz_class_word" with "word"
    And I press "Submit"
    And I wait 1 second
    Then I should see "By joining this class, the teacher John Nash will be able to see all of your current and future work. If do not want to share your work, but do want to join the class please create a second account and use it to join the class"
    And I should see "Click 'Join' to continue registering for this class."
    And I should not see "Please enter a valid class word and try again."
    When I press "Join"
    Then I should see "Successfully registered for class."
    And the student "student" should belong to the class "My Class"
