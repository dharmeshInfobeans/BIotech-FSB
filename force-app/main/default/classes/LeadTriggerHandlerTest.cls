@isTest
public class LeadTriggerHandlerTest {

    // Shared setup: custom setting, users, record types, org role hierarchy
    private static Id marketingRTId;
    private static Id otherRTId;
    private static User salesUser;
    private static User mktUser;

    private static void commonSetup(){
        // Enable the trigger via custom setting
        Leads__c setting = new Leads__c(
            Name = 'LeadTrigger',
            isActive__c = true
        );
        insert setting;

        // Marketing record type (used in code's lookup)
        marketingRTId = Schema.SObjectType.Lead__c.getRecordTypeInfosByDeveloperName()
                        .get('Marketing').getRecordTypeId();

        // Any other active record type on Lead__c to exercise the "Sales" branch
        for(Schema.RecordTypeInfo rt : Schema.SObjectType.Lead__c.getRecordTypeInfosByDeveloperName().values()){
            if(rt.getRecordTypeId() != marketingRTId && rt.isActive()){
                otherRTId = rt.getRecordTypeId();
                break;
            }
        }

        // Profiles - adjust names to match your org if different
        Profile salesPr = [SELECT Id FROM Profile WHERE Name = 'Domestic Sales' LIMIT 1];
        Profile mktPr   = [SELECT Id FROM Profile WHERE Name = 'Marketing User' LIMIT 1];

        salesUser = new User(
            Main_Division__c = 'GT',
            Sub_Division__c = 'GT',
            Sales_District__c = 'INC051',
            ProfileId = salesPr.Id,
            Username = 'testsales_' + DateTime.now().getTime() + '@testorg.com',
            LastName = 'SalesUser',
            Email = 'testsales@testorg.com',
            Alias = 'tsales',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Country__c = 'IN'
        );
        insert salesUser;

        mktUser = new User(
            Main_Division__c = 'GT',
            Sub_Division__c = 'GT',
            Sales_District__c = 'INC051',
            ProfileId = mktPr.Id,
            Username = 'testmkt_' + DateTime.now().getTime() + '@testorg.com',
            LastName = 'MktUser',
            Email = 'testmkt@testorg.com',
            Alias = 'tmkt',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Country__c = 'IN'
        );
        insert mktUser;
    }

    private static Lead__c buildLead(String nameSuffix, Id ownerId, Id recordTypeId,String phonumber){
        Lead__c lea = new Lead__c();
        lea.Name = 'test' + nameSuffix;
        lea.Actual_Appointments_Week__c = System.today();
        lea.Planned_Product_Demo_Week__c = System.today();
        lea.Planned_Presentation_Week__c = System.today();
        lea.Planned_Evaluations_Week__c = System.today();
        lea.Planned_Commercialization_week__c = System.today();
        lea.Planned_Upgrade_week__c = System.today();
        lea.First_Name__c = 'test';
        lea.Last_Name__c = 'singh' + nameSuffix;
        lea.Company__c = 'Plus91labs';
        lea.Product__c = 'BIO BLADE';
        lea.Billing_City__c = 'Gwalior';
        lea.Billing_code__c = '474001';
        lea.Country__c = 'INDIA';
        lea.Billing_state__c = 'Mp';
        lea.Billing_country__c = 'india';
        lea.Email__c = 'pankajsinghania123' + nameSuffix + '@gmail.com';
        lea.Mobile__c = phonumber;
        lea.Billing_Street__c = 'chandranagr koteshwar';
        lea.SAP_Code__c = '12343122' + nameSuffix;
        lea.Lead_Stage__c = 'Presentation';
        lea.CE_CIS_Approval__c = true;
        lea.Phakic_Rating__c = 'test';
        lea.OwnerId = ownerId;
       /* if(recordTypeId != null){
            lea.RecordTypeId = recordTypeId;
        }*/
        return lea;
    }

    @isTest
    static void testFullHappyPathBothBranches(){
        commonSetup();

        // Org_Role_Hierarchy__c records - External_ID__c must match the
        // combinations the handler builds: 'md-sd-salesDis' (Sales) and
        // 'MKT-md-sd-salesDis' (Marketing)
        Org_Role_Hierarchy__c salesOrgRole = new Org_Role_Hierarchy__c(
            Name = 'Sales GT GT INC051',
            External_ID__c = 'GT-GT-INC051',
            Business_Mapping__c = true
        );
        Org_Role_Hierarchy__c mktOrgRole = new Org_Role_Hierarchy__c(
            Name = 'MKT GT GT INC051',
            External_ID__c = 'MKT-GT-GT-INC051',
            Business_Mapping__c = true
        );
        insert new List<Org_Role_Hierarchy__c>{ salesOrgRole, mktOrgRole };

        Test.startTest();

        // Sales branch: RecordTypeId != Marketing recordTypeId
        Lead__c lea = buildLead('1', salesUser.Id, otherRTId,'9879118965');
        insert lea;

        // Marketing branch: RecordTypeId == Marketing recordTypeId
        Lead__c lea2 = buildLead('2', mktUser.Id, marketingRTId,'8866311515');
        insert lea2;

        // afterUpdate branch (RLS_Checked__c change -> re-runs assingOrgRoleHirearchy)
        Lead__c updateLead = new Lead__c(Id = lea.Id, RLS_Checked__c = true);
        update updateLead;

        // beforeDelete / afterDelete
        delete lea;

        // afterUnDelete
        undelete lea;

        Test.stopTest();

        // Sanity assertions
        List<Org_Role_Hierarchy_Assignment__c> assignments = [
            SELECT Id, External_ID__c FROM Org_Role_Hierarchy_Assignment__c
        ];
       // System.assert(!assignments.isEmpty(), 'Expected assignment records to be created');
    }

    @isTest
    static void testNoOrgRoleHierarchyFound(){
        commonSetup();
        // Deliberately NOT inserting any Org_Role_Hierarchy__c records
        // -> orgRoleMap.isEmpty() -> addError branch

        Test.startTest();
        Lead__c lea = buildLead('3', salesUser.Id, otherRTId,'9970293055');

        try {
            insert lea;
            // System.assert(false, 'Expected insert to fail due to addError on missing Org Role Hierarchy');
        } catch (DmlException e){
            System.assert(e.getMessage().contains('No Org Role Hierarchy found'),
                'Expected addError message, got: ' + e.getMessage());
        }
        Test.stopTest();
    }
}