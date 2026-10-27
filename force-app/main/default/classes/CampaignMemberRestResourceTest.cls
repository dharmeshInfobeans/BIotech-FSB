@isTest
private class CampaignMemberRestResourceTest {
    @isTest
    static void testUpsertCampaignMember() {
        // Step 1: Create test data for Campaign__c
        Target__c tar=new Target__c();
        //   tar.Activity_Type__c='Other';
        tar.Date__c=system.today();
        tar.Month__c='January';
        insert tar;
        Campaign__c testCampaign = new Campaign__c(
            Name = 'New Test',
        Executer__c = UserInfo.getUserId(),
        Start_Date__c = Date.newInstance(2023, 5, 17),
        End_Date__c = Date.newInstance(2023, 5, 20),
        Focus_Product__c = 'EYECRYL PHAKIC TORIC;OPTIFLEX TRIO;EYECRYL SERT EDOF;OPTIFLEX GENESIS COMFORT',
        Operation__c = 'Direct',
        Region__c = 'APAC',
        Categorize__c = 'Biotech Driven Event',
        Zone__c = 'EAST',
        State__c = 'West Bengal',
        City__c = 'Kolkata',
        Planned_Attendees__c = 50,
        Description__c = 'Test Campaign Description',
        Country__c = 'INDIA',
        Activity_Type__c = 'CME',
        Group__c='ACCESS TO INNOVATION SERIES',
        Target__c= tar.Id,
        List_Of_Activities__c = 'CME'
            );
        insert testCampaign;
        
        // Step 2: Create test Contact data
        Contact testContact = new Contact(
            FirstName = 'test123',
        LastName = 'Vanessa Lopez Torres',
        Email = 'cuentasporpagar@clinicaofta.com',
        MobilePhone = '3185230017',
        MailingStreet = 'CR 47 8C 94',
        MailingCity = 'CALI',
        MailingState = 'CALI',
        MailingPostalCode = '760001',
        MailingCountry = 'Colombia'
            );
        insert testContact;
        
        // Step 3: Prepare the input data for the API
        List<CampaignMemberRestResource.CampaignMemberWrapper> wrapperList = new List<CampaignMemberRestResource.CampaignMemberWrapper>();
        CampaignMemberRestResource.CampaignMemberWrapper wrapper = new CampaignMemberRestResource.CampaignMemberWrapper();
        wrapper.campaignId = testCampaign.Id;
        wrapper.campaignProduct = 'EYECRYL PHAKIC TORIC';
        wrapper.firstName = 'test123';
        wrapper.lastName = 'Vanessa Lopez Torres';
        wrapper.emailId = 'cuentasporpagar@clinicaofta.com';
        wrapper.street = 'CR 47 8C 94';
        wrapper.city = 'CALI';
        wrapper.state = 'CALI';
        wrapper.mobile = '3185230017';
        wrapper.zipCode = '760001';
        wrapper.country = 'Colombia';
        wrapper.attended = false;
        wrapper.campaignMemberId = null;
        wrapper.timeSlot = '<comma_separated_values>';
        wrapperList.add(wrapper);
        
        // Step 4: Test the API method
        Test.startTest();
        List<CampaignMemberRestResource.CampaignMemberResponseWrapper> responseList = CampaignMemberRestResource.upsertCampaignMember(wrapperList);
        Test.stopTest();
        
        // Step 5: Validate the results
        System.assertEquals(1, responseList.size(), 'There should be 1 response record');
        CampaignMemberRestResource.CampaignMemberResponseWrapper response = responseList[0];
        System.assertNotEquals(null, response.campaignMemberId, 'CampaignMemberId should not be null');
        System.assertEquals(testCampaign.Id, response.campaignId, 'Campaign ID should match');
        System.assertEquals('3185230017', response.mobile, 'Mobile number should match');
        // System.assertEquals(true, response.attendanceMarked, 'Attendance should be marked as true');
        
        // Query Campaign Member to validate data persistence
        Campaign_Member__c insertedMember = [SELECT Id, Lead_First_Name__c, Lead_Email__c, Campaign_Product__c, Attended__c
                                             FROM Campaign_Member__c
                                             WHERE Id = :response.campaignMemberId LIMIT 1];
        System.assertEquals('test123', insertedMember.Lead_First_Name__c, 'First Name should match');
        System.assertEquals('cuentasporpagar@clinicaofta.com', insertedMember.Lead_Email__c, 'Email should match');
        System.assertEquals('EYECRYL PHAKIC TORIC', insertedMember.Campaign_Product__c, 'Campaign product should match');
        System.assertEquals(false, insertedMember.Attended__c, 'Attended should be false');
    }
    
    @isTest
    static void testUpsertCampaignMemberWithEmptyWrapper() {
        Test.startTest();
        try {
            CampaignMemberRestResource.upsertCampaignMember(null);
            System.assert(false, 'Expected exception for null input');
        } catch (Exception e) {
            System.assertEquals('Invalid input data: Wrapper list is empty or null', e.getMessage());
        }
        Test.stopTest();
    }
}