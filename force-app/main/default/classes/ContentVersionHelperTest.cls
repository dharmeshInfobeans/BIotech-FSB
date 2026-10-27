@isTest
public class ContentVersionHelperTest {
    
    @isTest
    static void testGeneratePublicUrl() {
        
        Leads__c setting = new Leads__c(
            Name = 'ContentVersionTrigger', 
            IsActive__c = true
        );
        insert setting;
        
        Target__c target = new Target__c(
            Name = 'Test Target',
            Date__c = Date.today()
        );
        insert target;
        
         Campaign__c camp = new Campaign__c(
            Name = 'Test Campaign',
            categorize__c = 'Biotech Driven Event',
            Target__c = target.Id,
            Activity_Type__c = 'CONFERENCES', 
            Country__c = 'IN',
            Operation__c = 'Direct',
            Region__c = 'APAC',
            State__c = 'Madhya Pradesh',
            Zone__c = 'North'
        );
        insert camp;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Data'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = camp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        
        ContentVersion cv2 = new ContentVersion(
            Title = 'Test File 2',
            PathOnClient = 'TestFile2.pdf',
            VersionData = Blob.valueOf('Test Data 2'),
            IsMajorVersion = true,
            ContentDocumentId = cv.ContentDocumentId
        );
        
        Test.startTest();
        insert cv2;
        Test.stopTest();
        
        List<ContentDistribution> distList = [
            SELECT Id, DistributionPublicUrl, ContentVersionId
            FROM ContentDistribution
        ];
        System.assert(distList.size() > 0, 'ContentDistribution should be created');
        
        Campaign__c updatedCamp = [
            SELECT Public_File_Url__c, Content_version_Id__c
            FROM Campaign__c
            WHERE Id = :camp.Id
        ];
        
        System.assertNotEquals(null, updatedCamp.Public_File_Url__c, 'Public URL should be set');
        System.assertNotEquals(null, updatedCamp.Content_version_Id__c, 'Version Id should be set');
    }
}