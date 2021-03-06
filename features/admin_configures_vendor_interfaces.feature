Feature: The Project administrator disables certain vendor interfaces
  As a Investigations project admin
  I want modify the list of supported vendor interfaces
  So that I can provide a smaller list of well tested interfaces

  Background:
    Given The default settings and jnlp resources exist using factories
    And the database has been seeded

  @javascript
  Scenario: The project administrator removes some probe interfaces
    Given the following students exist:
      | login        | password            |
      | student_login| student_password    |
    And I login as an admin
    And the following vendor interfaces exist:
      | name             | description              |
      | pasco usb        | a pasco usb interface    |
      | vernier usb      | a vernier usb interface  |
      | radios hack RS232| old school interface     |
      | Texas Instruments| good old TI interface    |
      | pasco bluetooth  | pasco in the house       |
    And the current settings is using the following interfaces:
      | name             |
      | pasco usb        |
      | vernier usb      |
      | radios hack RS232|
      | Texas Instruments|
      | pasco bluetooth  |
    When I go to the current settings edit page
    Then I should see "Default Settings"
    And I should see "Vendor Interfaces"
    Then I should see the following form checkboxes:
      | name              | checked |
      | pasco usb         | true    |
      | vernier usb       | true    |
      | radios hack RS232 | true    |
      | Texas Instruments | true    |
      | pasco bluetooth   | true    |
    When I check in the following:
      | name             | checked |
      | pasco usb        | true    |
      | vernier usb      | true    |
      | radios hack RS232| false   |
      | Texas Instruments| false   |
      | pasco bluetooth  | true    |
    And I press "Save"
    Then I should see "Settings was successfully updated"
    When I go to the current settings edit page
    Then I should see the following form checkboxes:
      | name             | checked |
      | pasco usb        | true    |
      | vernier usb      | true    |
      | radios hack RS232| false   |
      | Texas Instruments| false   |
      | pasco bluetooth  | true    |

  Scenario: The student user can only select configured interfaces
    Given the following students exist:
      | login          | password            |
      | student_login | student_password    |
    And the following vendor interfaces exist:
      | name             | description              |
      | pasco usb        | a pasco usb interface    |
      | vernier usb      | a vernier usb interface  |
      | radios hack RS232| old school interface     |
      | Texas Instruments| good old TI interface    |
      | pasco bluetooth  | pasco in the house       |
    And the current settings is using the following interfaces:
      | name             |
      | pasco usb        |
      | vernier usb      |

    When I login with username: student_login
    When I follow "Settings"
    Then I should see "User Preferences"
    And I should see "Probeware Interface"
    Then I should have the following selection options:
      | option           |
      | pasco usb        |
      | vernier usb      |
    And I should not see the following selection options:
      | option           |
      | radios hack RS232|
      | Texas Instruments|
      | pasco bluetooth  |
