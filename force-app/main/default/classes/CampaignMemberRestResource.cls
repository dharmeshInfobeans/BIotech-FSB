@RestResource(urlMapping='/CampaignMember/*')
global without sharing class CampaignMemberRestResource {
    
    // Wrapper class to encapsulate campaign member data
    global class CampaignMemberWrapper {
        public String campaignMemberId { get; set; }  // Added campaignMemberId to wrapper
        public String campaignId { get; set; }
        public String campaignProduct { get; set; }
        public String firstName { get; set; }
        public String lastName { get; set; }
        public String hospitalClinicName { get; set; }
        public String emailId { get; set; }
        public String street { get; set; }
        public String city { get; set; }
        public String state { get; set; }
        public String mobile { get; set; }
        public String zipCode { get; set; }
        public String country { get; set; }
        public Boolean attended { get; set; }
        public String memberType { get; set; }
        public String timeSlot { get; set; }
    }
    
    // Response wrapper to send campaign member records after successful insertion
    global class CampaignMemberResponseWrapper {
        public String campaignId { get; set; }
        public String mobile { get; set; }
        public String campaignMemberId { get; set; }
        public String errorMessage { get; set; }
    }
    
    @HttpPatch
    global static List<CampaignMemberResponseWrapper> upsertCampaignMember(List<CampaignMemberWrapper> wrapperList) {
        // Validate input
        if (wrapperList == null || wrapperList.isEmpty()) {
            NoDataFoundException e= new NoDataFoundException();
            e.setMessage('Invalid input data: Wrapper list is empty or null');
            throw e;
        }
        
        // Step 1: Collect Campaign Member IDs, Emails, and Mobiles from the wrappers
        Set<String> campaignMemberIds = new Set<String>();
        Set<String> emailIds = new Set<String>();
        Set<String> mobileNumbers = new Set<String>();
        
        for (CampaignMemberWrapper wrapper : wrapperList) {
            if (wrapper == null) {
                NoDataFoundException e= new NoDataFoundException();
                e.setMessage('Invalid input data');
                throw e;
            }
            
            if (!String.isBlank(wrapper.campaignMemberId)) {
                campaignMemberIds.add(wrapper.campaignMemberId);
            }
            
            // Collect email and mobile separately
            if (!String.isBlank(wrapper.emailId)) {
                emailIds.add(wrapper.emailId);
            }
            if (!String.isBlank(wrapper.mobile)) {
                mobileNumbers.add(wrapper.mobile);
            }
        }
        
        // Step 2: Query for existing Campaign Members by IDs
        Map<String, Campaign_Member__c> existingCampaignMembers = new Map<String, Campaign_Member__c>();
        if (!campaignMemberIds.isEmpty()) {
            for (Campaign_Member__c cm : [SELECT Id, Campaign1__c, Campaign_Product__c, Lead_First_Name__c, Lead_Last_Name__c,
                                                 Lead_Email__c, Lead_Street__c, Lead_City__c, Lead_State_Province__c,
                                                 Lead_Mobile_Number__c, Lead_Zip_Postal_Code__c, Lead_Country__c,Lead_Hospital_Clinic_Name__c,
                                                 Attended__c, Member_Type__c, Time_Slots__c
                                          FROM Campaign_Member__c
                                          WHERE Id IN :campaignMemberIds]) {
                existingCampaignMembers.put(cm.Id, cm);
            }
        }
        
        // Step 3: Query for Contacts by email and mobile separately
        Map<String, Contact> emailContactMap = new Map<String, Contact>();
        Map<String, Contact> mobileContactMap = new Map<String, Contact>();
        
        if (!emailIds.isEmpty()) {
            for (Contact c : [SELECT Id, AccountId, Email FROM Contact WHERE Email IN :emailIds]) {
                emailContactMap.put(c.Email, c);
            }
        }
        
        if (!mobileNumbers.isEmpty()) {
            for (Contact c : [SELECT Id, AccountId, MobilePhone FROM Contact WHERE MobilePhone IN :mobileNumbers]) {
                mobileContactMap.put(c.MobilePhone, c);
            }
        }
        
        // Step 4: Process the wrappers and prepare Campaign Members for upsert
        List<Campaign_Member__c> membersToUpsert = new List<Campaign_Member__c>();
        List<CampaignMemberResponseWrapper> responseList = new List<CampaignMemberResponseWrapper>(); // To store the response
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        
        // Query RecordType object to get all record types for the custom object
        for (RecordType rt : [SELECT Id, DeveloperName, Name FROM RecordType WHERE SObjectType = 'Campaign_Member__c']) {
            recordTypeMap.put(rt.DeveloperName, rt.Id);
        }
        for (CampaignMemberWrapper wrapper : wrapperList) {
            Campaign_Member__c cm;
            
            // Fetch existing campaign member if it exists, else create new
            if (!String.isBlank(wrapper.campaignMemberId) && existingCampaignMembers.containsKey(wrapper.campaignMemberId)) {
                
                System.debug('wrapper.campaignMemberId101'+wrapper.campaignMemberId);
                cm = existingCampaignMembers.get(wrapper.campaignMemberId);
            } else {
                cm = new Campaign_Member__c();
                cm.Campaign1__c=wrapper.campaignId;
                
                
                // Assign contact by email or mobile if available
                if (!String.isBlank(wrapper.emailId) && emailContactMap.containsKey(wrapper.emailId)) {
                    Contact contact = emailContactMap.get(wrapper.emailId);
                    cm.Contact__c = contact.Id;
                    cm.Account__c = contact.AccountId;
                    cm.RecordTypeId=recordTypeMap.get('Existing_member');
                } else if (!String.isBlank(wrapper.mobile) && mobileContactMap.containsKey(wrapper.mobile)) {
                    Contact contact = mobileContactMap.get(wrapper.mobile);
                    cm.Contact__c = contact.Id;
                    cm.Account__c = contact.AccountId;
                    cm.RecordTypeId=recordTypeMap.get('Existing_member');
                    
                }else{
                    cm.RecordTypeId=recordTypeMap.get('New_member');
                    
                }
            }
            
            // Update the fields from wrapper
            cm.Campaign_Product__c = wrapper.campaignProduct!=null?wrapper.campaignProduct:cm.Campaign_Product__c;
            cm.Lead_First_Name__c = wrapper.firstName!=null?wrapper.firstName:cm.Lead_First_Name__c;
            cm.Lead_Last_Name__c = wrapper.lastName!=null?wrapper.lastName:cm.Lead_Last_Name__c;
            cm.Lead_Hospital_Clinic_Name__c = wrapper.hospitalClinicName!=null?wrapper.hospitalClinicName:cm.Lead_Hospital_Clinic_Name__c;
            cm.Lead_Email__c = wrapper.emailId!=null?wrapper.emailId:cm.Lead_Email__c;
            cm.Lead_Street__c = wrapper.street!=null?wrapper.street:cm.Lead_Street__c;
            cm.Lead_City__c = wrapper.city!=null?wrapper.city:cm.Lead_City__c;
            cm.Lead_State_Province__c = wrapper.state!=null?wrapper.state:cm.Lead_State_Province__c;
            cm.Lead_Mobile_Number__c = wrapper.mobile!=null?wrapper.mobile:cm.Lead_Mobile_Number__c;
            cm.Lead_Zip_Postal_Code__c = wrapper.zipCode!=null?wrapper.zipCode:cm.Lead_Zip_Postal_Code__c;
            cm.Lead_Country__c = wrapper.country!=null?wrapper.country:cm.Lead_Country__c;
            cm.Attended__c = wrapper.attended!=null?wrapper.attended:cm.Attended__c;
            cm.Member_Type__c = wrapper.memberType!=null?wrapper.memberType:cm.Member_Type__c;
            cm.Time_Slots__c = wrapper.timeSlot!=null?wrapper.timeSlot:cm.Time_Slots__c;
            
            membersToUpsert.add(cm);
            
            // Prepare the response wrapper (initialize with success data, errors will be added later)
            CampaignMemberResponseWrapper responseWrapper = new CampaignMemberResponseWrapper();
            responseWrapper.campaignId = wrapper.campaignId;
            responseWrapper.mobile = wrapper.mobile;

            responseWrapper.campaignMemberId = wrapper.campaignMemberId; // Temporary, real ID after upsert
            responseList.add(responseWrapper);
        }
        
        // Step 5: Upsert campaign members and handle errors
        try {
            Database.UpsertResult[] upsertResults = Database.upsert(membersToUpsert,false); // Upsert with partial success
            
            // Step 6: Process results and update the response wrapper
            for (Integer i = 0; i < upsertResults.size(); i++) {
                if (upsertResults[i].isSuccess()) {
                    // If successful, update the response wrapper with the real campaign member ID
                    responseList[i].campaignMemberId = upsertResults[i].getId();

                } else {
                    // If failed, update the response wrapper with the error message
                    Database.Error[] errors = upsertResults[i].getErrors();

                    responseList[i].errorMessage = 'Error: ' + errors[0].getMessage(); // Only capturing the first error
                }
            }
            
            return responseList; // Return the response with both successes and errors
        } catch (Exception e) {
            throw e;
        }
    }
}