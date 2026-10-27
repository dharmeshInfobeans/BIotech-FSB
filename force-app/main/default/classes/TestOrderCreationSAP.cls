@isTest
public class TestOrderCreationSAP{
    @testSetup
    static void testDataCreate(){
        Id systemAdminProfileId = [SELECT Id
                                   FROM Profile
                                   WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id
                                           FROM Profile
                                           WHERE Name = 'Biotech Partner Community'].Id;
        Id RBMRoleId = [SELECT Id
                        FROM UserRole
                        WHERE (Name like 'RSM Gujarat%')
                        LIMIT 1].Id;
        
        User systemAdmin = IB_TestDataFactory.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-86573', 'I;II;III;IV;V', null);
        
        System.runAs(systemAdmin){
            
            
            CIty__c MiamiRegion = IB_TestDataFactory.createRegionData('Miami', '90', 'US');
            
                        List<CIty__c> MiamiRegionList = IB_TestDataFactory.createRegionData(1,'Miami', '80', 'US');
            Id dealerAccountRecordTypeId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
            Account internationalAcc = IB_TestDataFactory.createAccForInternational(MiamiRegion, '873890');
            internationalAcc.RecordTypeId=dealerAccountRecordTypeId;
            update internationalAcc;
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');
            //create plant
            Plant__c plant1 = IB_TestDataFactory.createPlantdata('1100-BTVCPL Unit-1', 'Ahmedabad, India', 'India');
            
            //create product list
            List<Product__c> prodLst = new List<Product__c>();
            Product__c testProd1 = IB_TestDataFactory.createProductData('V', 'International', 'EP096', 'Eyecryl Phakic');
            //testProd1.Incoterms__c = 'CIF';
            testProd1.plant__c = plant1.Id;
            prodLst.add(testProd1);
            Product__c testProd2 = IB_TestDataFactory.createProductData('I', 'International', 'EP096', 'Eyecryl Plus 600');
            testProd2.Name = 'Test345';
            testProd2.plant__c = plant1.Id;
            prodLst.add(testProd2);
            //product list
            update prodLst;
            
            //Creating Product model
            Product_Model__c productModel1 = IB_TestDataFactory.createProductModelData(testProd1.Id, 'B0702312');
            // Creating Product_Material_Stock__c
            Product_Material_Stock__c productMS = IB_TestDataFactory.createProductMaterialStockData('a1LBl0000009XeH', '12BLD005', plant1.Id, productModel1.Id);
            Product_Material_Stock__c productMS2 = IB_TestDataFactory.createProductMaterialStockData('a1LBl0000009XeH', '12BLD004', plant1.Id, productModel1.Id);
            
            Integer day = Date.today().Day();
            Date startDate = Date.newInstance(Date.today().Year(), Date.today().Month(), day - 1);
            Date endDate = Date.newInstance(Date.today().Year(), Date.today().Month(), day + 1);
            //creating master aggriment
            List<Master_Agreement__c> masterAgreements = IB_TestDataFactory.createMasterAgreements(internationalAcc.Id, startDate, endDate, 2);
            masterAgreements[0].Agreement_Signed_With__c = 'Biotech Healthcare Holding GmbH';
            update masterAgreements[0];
            Agreement_Product__c agreementProd1 = IB_TestDataFactory.createAgreementProductForPoducts(testProd1.Id, masterAgreements[0].id);
            Agreement_Product__c agreementProd2 = IB_TestDataFactory.createAgreementProductForPoducts(testProd2.Id, masterAgreements[1].id);
            
            Id buyerAccountRecordTypeId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Buyer Account').getRecordTypeId();
              Account acc2 = new Account();
                acc2.Name = 'Buyer';
                acc2.Contact_Person__c='test';
                acc2.First_mobile_telephone_no__c='3435';
                acc2.ParentId = internationalAcc.Id;
                acc2.Parent_Customer__c = internationalAcc.Id;
                acc2.RecordTypeId = buyerAccountRecordTypeId;
                acc2.BillingCity = 'Test test';
                acc2.BillingCountry =  'Test';
                insert acc2;
                
                    //order creation
                Order__c ord = new Order__c(Account__c = internationalAcc.Id, Is_it_ok_to_cancel_old_Draft_Orders__c = true,Buyer_Account__c = acc2.Id);
                
            insert ord;
            
            //create Fright
            Freight_Request__c frightRequest1 = IB_TestDataFactory.createFreightRequestData(ord.Id, plant1.Id, 'Test123');
            frightRequest1.Products__c =frightRequest1.Products__c+','+testProd2.Name;
            update frightRequest1;
            //create order Products
            //creating Parent Product record
            Order_Product__c op1 = IB_TestDataFactory.createOrderProductData(ord.Id, false, agreementProd1.Id, testProd1.Id, '10', '0.25', 6, 'B0702312');
            
            SAP_Creds__c sapCred = new SAP_Creds__c();
            sapCred.Endpoint__c = 'https://httpbin.org/post';
            sapCred.Username__c = 'miuser';
            sapCred.Password__c = 'password@123';
            sapCred.Environment_Name__c = 'Dev';
            sapCred.Name = 'SAP_Quality';
            
            insert sapCred;
            
            
        }
    }
    
    @isTest
    public static void TstOrderCreationSAP(){
        Order__c orderRec = [select id, order_date__c
                             from Order__c
                             LIMIT 1];
        
        System.debug('orderRecId' + orderRec.Id);
        Test.setMock(HttpCalloutMock.class, new OrderCreationSapCalloutMock());
        
        OrderCreationSAP orderInstance = new OrderCreationSAP();
        
        OrderCreationSAP.sendOrderData(orderRec.Id);
        
        // System.assertEquals(200, response.getStatusCode(), 'sendOrderData method test case passed');
    }
    @isTest
    public static void TestOrderCreationSAPNegative(){
        
        try {
            OrderCreationSAP.sendOrderData(NUll);        // set body
        }
        catch (Exception e) {
            system.debug('BG >>> e: '+e.getMessage());
            
        }            
    } 
    
    
    
    // System.assertEquals(200, response.getStatusCode(), 'sendOrderData method test case passed');




}