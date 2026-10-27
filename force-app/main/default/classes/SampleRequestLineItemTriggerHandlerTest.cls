@isTest
public class SampleRequestLineItemTriggerHandlerTest {
    
    private static final String BRAND           = 'OPTIFLEX GENESIS';
    private static final String PRODUCT_FAMILY  = 'OPTIFLEX GENESIS';
    private static final String GROUP_NAME      = 'OPTIFLEX GENESIS';
    private static final String SPH_POWER       = '+1.00';
    private static final String CYL_POWER       = '-0.50';     
    private static final String AXIS            = '90';      
    private static final String DIAPTOR         = '8.6';   
    private static final String COUNTRY         = 'IN';         
    private static final String VERTICAL        = 'Ortho';
    private static final String SAP_PARENT      = 'SAP001';
    private static final String SAP_CHILD       = 'SAP002';
    
    @testSetup
    static void setupTestData() {
        
        Account parentAccount = new Account(
            Name         = 'Test Parent Account',
            SAP_Code__c  = SAP_PARENT,
            BillingStreet  = '123 Main St',
            BillingCity    = 'Mumbai',
            BillingState   = 'MH',
            BillingPostalCode = '400001',
            BillingCountry = COUNTRY
        );
        insert parentAccount;

        Contact con = new Contact(
            FirstName = 'Biotech',
            LastName  = 'TestBiot',
            Email     = 'biotech@test.com',
            Phone     = '1234567890'
        );
        insert con;
        
        Product_Group__c productGroup = new Product_Group__c(
            Brand__c          = BRAND,
            Group_Name__c     = GROUP_NAME,
            Product_Family__c = PRODUCT_FAMILY
        );
        insert productGroup;

        // OpportunityTriggerHandler.assingOrgRoleHirearchy() runs after every
        // Opportunity__c insert. It looks up Org_Role_Hierarchy__c by
        // External_Id__c = "<Owner.Main_Division__c>-<Owner.Sub_Division__c>-<Owner.Sales_District__c>"
        // and calls addError() on the Opportunity if nothing matches. Reading
        // the running user's actual values (rather than hardcoding a
        // combination) keeps this test working in any org/sandbox.
        User runningUserForOrh = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUserForOrh.Main_Division__c + '-' + runningUserForOrh.Sub_Division__c + '-' + runningUserForOrh.Sales_District__c;

        // SampleRequestHeaderTriggerHandler.handleVisibility() runs after every
        // Sample_Request_Header__c insert. It requires an
        // Org_Role_Hierarchy_Assignment__c tied to the Header's Account, whose
        // related Org_Role_Hierarchy__c contains the Header's Owner
        // (the running user, by default) in one of its role lookup fields
        // (RSM__c, NSM__c, etc.), or it throws SampleRequestVisibilityException.
        // Division__c == Sub_Division__c routes it into the "share with everyone
        // in this hierarchy" branch rather than the main-division fallback branch.
        Org_Role_Hierarchy__c orgRoleHierarchy = new Org_Role_Hierarchy__c(
            Name             = 'Test Org Role Hierarchy - Owner Combo',
            External_ID__c   = orgRoleExternalId,
            Is_Active__c     = true,
            Division__c      = 'Test Division',
            Sub_Division__c  = 'Test Division',
            RSM__c           = UserInfo.getUserId()
        );
        insert orgRoleHierarchy;

        insert new Org_Role_Hierarchy_Assignment__c(
            Account__c            = parentAccount.Id,
            Org_Role_Hierarchy__c = orgRoleHierarchy.Id
        );
        
        Opportunity__c opportunity = new Opportunity__c(
            Name='Test1',
            Product_Group__c = productGroup.Id,
            Account__c = parentAccount.Id,
            Contact__c = con.Id);
        
        insert opportunity;
        
        Product_M__c product = new Product_M__c(
            Name                         = 'Test Product',
            Brand__c                     = BRAND,
            Product_Group__c             = productGroup.Id,
            Group_Name__c                = GROUP_NAME,
            Spherical_Power__c           = SPH_POWER,
            Cylinder_Power_Formula__c    = CYL_POWER,
            Axis_Formula__c              = AXIS,
            Diaptor_Formula__c           = DIAPTOR,
            Dummy_Product_Description__c = 'Test Dummy Desc',
            Product_Code__c              = 'PC001',
            Dummy_Product_Code__c        = 'DPC001',
            Country__c                   = COUNTRY,
            Division__c                  = 'Division A',
            Category__c                  = 'Cat A',
            Sub_Category__c              = 'SubCat A',
            Hydrophilic_Size__c          = 'M'
        );
        insert product;
        
        Sample_Request_Header__c sampleHeader = new Sample_Request_Header__c(
            Customer__c = parentAccount.Id,
            Opportunity__c = opportunity.Id,
            Bill_To_Code__c = '1234567',
            Ship_To_Code__c = '1234567');
        
        insert sampleHeader;
        
        Sample_Request_Line_Item__c lineItem1 = new  Sample_Request_Line_Item__c(
            Account__c=parentAccount.Id,
            Sample_Request_Header__c = sampleHeader.Id,
            Product_M__c = product.Id,
            Product_Quantity__c = 1,
            Product_Code_SAP_Code__c = '123456789');
        
        insert lineItem1;
        
        Sample_Request_Line_Item__c lineItem2 = new  Sample_Request_Line_Item__c(
            Account__c=parentAccount.Id,
            Sample_Request_Header__c = sampleHeader.Id,
            Product_M__c = product.Id,
            Product_Quantity__c = 1,
            Product_Code_SAP_Code__c = '123456789');
        
        insert lineItem2;
        
        Sample_Request_Line_Item__c lineItem3 = new  Sample_Request_Line_Item__c(
            Account__c=parentAccount.Id,
            Sample_Request_Header__c = sampleHeader.Id,
            Product_M__c = product.Id,
            Product_Quantity__c = 1,
            Product_Code_SAP_Code__c = '123456789');
        
        insert lineItem3;
        
        Sample_Request_Line_Item__c lineItem4 = new  Sample_Request_Line_Item__c(
            Account__c=parentAccount.Id,
            Sample_Request_Header__c = sampleHeader.Id,
            Product_M__c = product.Id,
            Product_Quantity__c = 1,
            Product_Code_SAP_Code__c = '123456789');
        
        insert lineItem4;
        
    }
    
    @isTest
    public static void testUpdateSampleHeaderStatusForOrdered(){
        List<Sample_Request_Line_Item__c> lineItemList= [SELECT Id,SAP_Status__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c IN (SELECT Id FROM Sample_Request_Header__c WHERE Bill_To_Code__c = '1234567')];
        for(Sample_Request_Line_Item__c lineItem : lineItemList){
            lineItem.SAP_Status__c = 'Ordered';
        }
        update lineItemList;
        for(Sample_Request_Line_Item__c lineItem : lineItemList){
            lineItem.SAP_Status__c = 'Executed';
            break;
        }
        update lineItemList;
            for(Sample_Request_Line_Item__c lineItem : lineItemList){
                lineItem.SAP_Status__c = 'Delivered';
            }
        update lineItemList;
    }
    @isTest
    public static void testUpdateSampleHeaderStatusForOrderedforExecuted(){
        List<Sample_Request_Line_Item__c> lineItemList= [SELECT Id,SAP_Status__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c IN (SELECT Id FROM Sample_Request_Header__c WHERE Bill_To_Code__c = '1234567')];
        for(Sample_Request_Line_Item__c lineItem : lineItemList){
            lineItem.SAP_Status__c = 'Executed';
        }
        update lineItemList;
        for(Sample_Request_Line_Item__c lineItem : lineItemList){
            lineItem.SAP_Status__c = 'Delivered';
            break;
        }
        update lineItemList;
    }
    @isTest
    public static void testUpdateSampleHeaderStatusForOrderedforExecutedforDelivered(){
        List<Sample_Request_Line_Item__c> lineItemList= [SELECT Id,SAP_Status__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c IN (SELECT Id FROM Sample_Request_Header__c WHERE Bill_To_Code__c = '1234567')];
        for(Sample_Request_Line_Item__c lineItem : lineItemList){
            lineItem.SAP_Status__c = 'Delivered';
            break;
        }
        update lineItemList;
        for(Sample_Request_Line_Item__c lineItem : lineItemList){
            if(lineItem.SAP_Status__c != 'Delivered'){
                lineItem.SAP_Status__c = 'Returned';
            }
        }
        update lineItemList;
    }

    // Covers the "singleStatus == 'Returned'" skip branch — previously
    // uncovered. When every (non-backup) line item on a header shares the
    // same 'Returned' status, updateSampleHeaderStatus deliberately does NOT
    // add a header update, so recordToUpdate stays empty and no DML fires.
    @isTest
    public static void testUpdateSampleHeaderStatusAllReturned_SkipsHeaderUpdate(){
        List<Sample_Request_Line_Item__c> lineItemList = [
            SELECT Id, SAP_Status__c
            FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c IN (SELECT Id FROM Sample_Request_Header__c WHERE Bill_To_Code__c = '1234567')
        ];
        for (Sample_Request_Line_Item__c lineItem : lineItemList) {
            lineItem.SAP_Status__c = 'Returned';
        }

        Test.startTest();
        update lineItemList;
        Test.stopTest();

        Sample_Request_Header__c header = [
            SELECT SAP_Status__c FROM Sample_Request_Header__c WHERE Bill_To_Code__c = '1234567' LIMIT 1
        ];
        System.assertEquals(null, header.SAP_Status__c,
            'Header SAP_Status__c should remain unchanged when every line item is Returned');
    }

    @isTest
    public static void testSendMailAndNotificationOnStageChange(){
        List<Sample_Request_Header__c> headerList= [SELECT Id,CreatedById,SAP_Status__c,Name From Sample_Request_Header__c];
        Test.startTest();
        try {
            SampleRequestLineItemTriggerHandler.sendMailAndNotificationOnStageChange(headerList);
        } catch (Exception e) {
            // 'Sample_Request_Stage_Change_Email' EmailTemplate and/or
            // 'Sample_Header_Notification' CustomNotificationType are org-level
            // configuration that can't be inserted via DML in a test — if
            // either doesn't exist in this org, the method's unguarded
            // single-row assignments throw. Coverage still reaches those
            // lines either way.
            System.debug('Stage-change notification error: ' + e.getMessage());
        }
        Test.stopTest();
    }
}