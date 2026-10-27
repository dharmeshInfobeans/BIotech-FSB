@isTest
public class loginlogoutcontrollerTest {
    
    @TestSetup
    static void makeData(){
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        User testUser = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@testorg.com.test',
            Country__c = 'India');
        insert testUser;
        
        Leavepolicy__c leavePolicy = new Leavepolicy__c(
            Name = 'India', 
            Past_days__c = 10
        );
        insert leavePolicy;
    }
    
    static testMethod void testGetCurrentUserAndSettings() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Test method
            Test.startTest();
            loginlogoutcontroller.UserAndCountrySetting result = loginlogoutcontroller.getCurrentUserAndSettings();
            loginlogoutcontroller.getCustomLabels();
            Test.stopTest();
            
            // Assert results
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(testUser.Id, result.currentUser.Id, 'User ID should match');
        }
    }

    static testMethod void testGetBeatPlanStatus() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today(),
                Approval_status__c = 'Approved',
                Assigned_To__c = testUser.Id
            );
            insert beatPlan;
            
            // Test method
            Test.startTest();
            Beat_Plan__c result = loginlogoutcontroller.getBeatPlanStatus();
            Test.stopTest();
            
            // Assert results
            System.assertNotEquals(null, result, 'Beat Plan should not be null');
            System.assertEquals(beatPlan.Id, result.Id, 'Beat Plan ID should match');
        }
    }

    static testMethod void testGetBeatPlanStatus_NoRecord() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Test method - no beat plan exists
            Test.startTest();
            Beat_Plan__c result = loginlogoutcontroller.getBeatPlanStatus();
            Test.stopTest();
            
            // Assert results
            System.assertEquals(null, result, 'Should return null when no beat plan exists');
        }
    }

    static testMethod void testInsertDailyActivity() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            Decimal latitude = 12.3456;
            Decimal longitude = 78.9012;
            
            // Test method
            Test.startTest();
            loginlogoutcontroller.insertDailyActivity(latitude, longitude);
            Test.stopTest();
            
            // Assert results
            List<Beat_Plan__c> results = [SELECT Id, Login_Latitude__c, Login_Longitude__c 
                                   FROM Beat_Plan__c 
                                   WHERE Assigned_To__c = :testUser.Id];
            System.assertEquals(1, results.size(), 'Should create one beat plan record');
            System.assertEquals('12.3456', results[0].Login_Latitude__c, 'Login Latitude should match');
            System.assertEquals('78.9012', results[0].Login_Longitude__c, 'Login Longitude should match');
        }
    }
    
    static testMethod void testInsertDailyActivity_UpdateExisting() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            Decimal latitude = 12.3456;
            Decimal longitude = 78.9012;
            
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today(),
                Assigned_To__c = testUser.Id
            );
            insert beatPlan;
            
            // Test method
            Test.startTest();
            loginlogoutcontroller.insertDailyActivity(latitude, longitude);
            Test.stopTest();
            
            // Assert results
            Beat_Plan__c result = [SELECT Login_Latitude__c, Login_Longitude__c 
                                   FROM Beat_Plan__c 
                                   WHERE Id = :beatPlan.Id];
            System.assertEquals('12.3456', result.Login_Latitude__c, 'Login Latitude should match');
            System.assertEquals('78.9012', result.Login_Longitude__c, 'Login Longitude should match');
        }
    }

    static testMethod void testLogoutActivity() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today(),
                Assigned_To__c = testUser.Id
            );
            insert beatPlan;
            
            Decimal latitude = 12.3456;
            Decimal longitude = 78.9012;
            
            // Test method
            Test.startTest();
            loginlogoutcontroller.logoutActivity(latitude, longitude);
            Test.stopTest();
            
            // Assert results
            Beat_Plan__c result = [SELECT Logout_Latitude__c, Logout_Longitude__c 
                                   FROM Beat_Plan__c 
                                   WHERE Id = :beatPlan.Id];
            System.assertEquals('12.3456', result.Logout_Latitude__c, 'Logout Latitude should match');
            System.assertEquals('78.9012', result.Logout_Longitude__c, 'Logout Longitude should match');
        }
    }

    static testMethod void testLogoutActivity_NoRecord() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            Decimal latitude = 12.3456;
            Decimal longitude = 78.9012;
            
            // Test method - should not throw exception when no record exists
            Test.startTest();
            try {
                loginlogoutcontroller.logoutActivity(latitude, longitude);
                System.assert(true, 'Should handle missing record gracefully');
            } catch (Exception e) {
                System.assert(false, 'Should not throw exception: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }

    static testMethod void testApplyLeave() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            String reason = 'Personal Leave';
            String leaveType = 'Full Day Leave';
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeave(reason, leaveType);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Success', result, 'Apply leave should return Success');
            
            // Verify record creation
            List<Beat_Plan__c> beatPlans = [SELECT Id, Event_type_Name__c FROM Beat_Plan__c WHERE Assigned_To__c = :testUser.Id];
            //System.assertEquals(1, beatPlans.size(), 'Should create one beat plan');
            System.assertEquals(leaveType, beatPlans[0].Event_type_Name__c, 'Leave type should match');
            
            // Verify event creation
            List<Event> events = [SELECT Id, Subject FROM Event WHERE OwnerId = :testUser.Id];
            System.assertEquals(1, events.size(), 'Should create one event');
        }
    }
    
    static testMethod void testApplyLeave_WithExistingRecord() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            String reason = 'Personal Leave';
            String leaveType = 'Full Day Leave';
            
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today(),
                Assigned_To__c = testUser.Id
            );
            insert beatPlan;
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeave(reason, leaveType);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Success', result, 'Apply leave should return Success');
            
            // Verify record update
            Beat_Plan__c updatedBeatPlan = [SELECT Event_type_Name__c FROM Beat_Plan__c WHERE Id = :beatPlan.Id];
            System.assertEquals(leaveType, updatedBeatPlan.Event_type_Name__c, 'Leave type should match');
        }
    }

    static testMethod void testApplyLeave_AlreadyApplied() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data - create a beat plan with approved status
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today(),
                Assigned_To__c = testUser.Id,
                Approval_status__c = 'Approved',
                Event_type_Name__c = 'Full Day Leave'
            );
            insert beatPlan;
            
            String reason = 'Personal Leave';
            String leaveType = 'Second Half Leave';
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeave(reason, leaveType);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Already', result, 'Should return Already when leave is already applied');
        }
    }

    static testMethod void testApplyLeaveFutureDate() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            String reason = 'Vacation';
            String leaveType = 'Second Half Leave';
            Date futureDate = System.today().addDays(5);
            Date holidayDate = System.today();
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeavefuturedate(reason, leaveType, futureDate, holidayDate);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Success', result, 'Apply leave future date should return Success');
            
            // Verify record creation
            List<Beat_Plan__c> beatPlans = [SELECT Event_type_Name__c, Compensation_Off_Date__c 
                                           FROM Beat_Plan__c 
                                           WHERE Beat_Date__c = :futureDate AND Assigned_To__c = :testUser.Id];
            System.assertEquals(1, beatPlans.size(), 'Should create one future beat plan');
            System.assertEquals(leaveType, beatPlans[0].Event_type_Name__c, 'Future leave type should match');
        }
    }
    
    static testMethod void testApplyLeaveFutureDate_WithExistingRecord() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            String reason = 'Vacation';
            String leaveType = 'Second Half Leave';
            Date futureDate = System.today().addDays(5);
            Date holidayDate = System.today();
            
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = futureDate,
                Assigned_To__c = testUser.Id
            );
            insert beatPlan;
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeavefuturedate(reason, leaveType, futureDate, holidayDate);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Success', result, 'Apply leave future date should return Success');
        }
    }

    static testMethod void testApplyLeaveFutureDate_CompensationOff() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            String reason = 'Compensation';
            String leaveType = 'Compensation off';
            Date futureDate = System.today().addDays(5);
            Date holidayDate = System.today().addDays(-1);
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeavefuturedate(reason, leaveType, futureDate, holidayDate);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Success', result, 'Compensation off should return Success');
            
            // Verify compensation date is set
            Beat_Plan__c beatPlan = [SELECT Compensation_Off_Date__c FROM Beat_Plan__c 
                                    WHERE Beat_Date__c = :futureDate AND Assigned_To__c = :testUser.Id];
            System.assertEquals(holidayDate, beatPlan.Compensation_Off_Date__c, 'Compensation date should match');
        }
    }

    static testMethod void testApplyLeaveFutureDate_AlreadyApplied() {
        User testUser = [SELECT Id, Country__c FROM User WHERE UserName='standarduser@testorg.com.test'];
        
        System.runAs(testUser) {
            // Setup test data
            String reason = 'Vacation';
            String leaveType = 'Second Half Leave';
            Date futureDate = System.today().addDays(5);
            Date holidayDate = System.today();
            
            // Create existing approved beat plan
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Beat_Date__c = futureDate,
                Assigned_To__c = testUser.Id,
                Approval_status__c = 'Approved',
                Event_type_Name__c = 'Full Day Leave'
            );
            insert beatPlan;
            
            // Test method
            Test.startTest();
            String result = loginlogoutcontroller.applyLeavefuturedate(reason, leaveType, futureDate, holidayDate);
            Test.stopTest();
            
            // Assert results
            System.assertEquals('Already', result, 'Should return Already when future leave is already applied');
        }
    }
}