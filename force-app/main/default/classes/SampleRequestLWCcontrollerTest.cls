@isTest
public class SampleRequestLWCcontrollerTest {
     @isTest
    public static void testFetchSampleRequestProductForLead() {
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO BLADE';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.rsm__c = UserInfo.getUserId();
        lea.ZSM__c =UserInfo.getUserId();
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Approval_status__c='Approved';
        lea.Aproved_By_Manager__c=true;
        lea.Lead_Stage__c='Upgrade';
        lea.CE_CIS_Approval__c=true;
         lea.Status__c=true;
        lea.New_Customer__c= true;
        lea.Billing_Street__c='test';
       
        insert lea;
                Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        
         Account accObj = new Account();
        accObj.Name = 'Test';
        accObj.AccountNumber = '12345678';
        accObj.rsm__c = UserInfo.getUserId();
        accObj.ZSM__c =UserInfo.getUserId();
        accObj.Street_2__c = 'street2';
        accObj.Street_3__c = 'street3';
        accObj.Street_4__c = 'street4';
        accObj.Street_5__c = 'street5';
        accObj.Country_Key__c='IN';
        accObj.City__c='mumbai';
        accObj.City_postal_code__c='400001';
        accObj.recordtypeid=RecordTypeIdContact;
        accObj.Branch__c = '';
        accObj.Sub_Status__c=  'Submitted To Approver 1';
        accObj.Medical_Registration_No__c='MEDREG123424567';
        accObj.GSTIN_No__c='GSTIN2343423456';
        accObj.SAP_Code__c='122322';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj;
        
              // Id RecordTypeIdContacts = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        
         Account accObj1 = new Account();
        accObj1.Name = 'Test';
        accObj1.AccountNumber = '12345678';
        accObj1.rsm__c = UserInfo.getUserId();
        accObj1.ZSM__c =UserInfo.getUserId();
        accObj1.Street_2__c = 'street2';
        accObj1.Street_3__c = 'street3';
        accObj1.Street_4__c = 'street4';
        accObj1.Street_5__c = 'street5';
        accObj1.Country_Key__c='IN';
        accObj1.City__c='mumbai';
        accObj1.City_postal_code__c='400001';
        accObj1.recordtypeid=RecordTypeIdContact;
        accObj1.Branch__c = '';
        accObj1.Sub_Status__c=  'Submitted To Approver 1';
        accObj1.Medical_Registration_No__c='MEDREG123424567';
        accObj1.GSTIN_No__c='GSTIN2343423456';
        accObj1.SAP_Code__c='122322';
        accObj1.ParentId = accObj.Id;
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj1;
        
        
        Sample_Request_Product__c sampleProduct = new Sample_Request_Product__c(
           // Product_Quantity__c =, // Set an appropriate integer value
            Country__c = 'INDIA',
            Sl_No__c = 12601,
            Divison__c = 'D5',
            Product_Code_SAP_Code__c = '12K30N16.0C0000A12',
            Product_Model__c = 'PC130T',
            Dummy_Product_Description__c = 'PHAKIC-TORIC',
            Dummy_ID_Code__c = 'D037',
            //Spherical_power__c = '5.0',
            //Hydrophilic_Size__c = '120.0',
            Business_Vertical__c = 'OPHTHALMOLOGY',
            Category__c = 'REFRACTIVE PRODUCTS',
            Sub_Category__c = 'Eyecryl PHAKIC TORIC',
            Brand__c = 'Eyecryl Phakic Toric',
            Group_Name__c = '(PC 130T)',
            Cylinder_Power__c = '0.2',
            Axis__c = '120.0',
            Diaptor__c = '16.0',
            Priority__c = 1 // Set an appropriate priority level
        );
        
        insert sampleProduct;
         Sample_Request_Product__c sampleProduct1 = new Sample_Request_Product__c(
            Product_Quantity__c = 1, // Set an appropriate integer value
            Country__c = 'INDIA',
            Sl_No__c = 12601,
            Divison__c = 'D5',
            Product_Code_SAP_Code__c = '12K30N16.0C0000A12',
            Product_Model__c = 'PC130T',
            Dummy_Product_Description__c = 'PHAKIC-TORIC',
            Dummy_ID_Code__c = 'D037',
           // Spherical_power__c = '5.0',
           // Hydrophilic_Size__c = '120.0',
            Business_Vertical__c = 'OPHTHALMOLOGY',
            Category__c = 'REFRACTIVE PRODUCTS',
            Sub_Category__c = 'Eyecryl PHAKIC TORIC',
            Brand__c = 'Eyecryl Phakic Toric',
            Group_Name__c = '(PC 130T)',
            Cylinder_Power__c = '0.2',
            Axis__c = '120.0',
            Diaptor__c = '16.0',
            Priority__c = 1 // Set an appropriate priority level
        );
        
        insert sampleProduct1;
         Sample_Request_Product__c sampleProduct2 = new Sample_Request_Product__c(
            Product_Quantity__c = 1, // Set an appropriate integer value
            Country__c = 'INDIA',
            Sl_No__c = 12601,
            Divison__c = 'D5',
            Product_Code_SAP_Code__c = '12K30N16.0C0000A12',
            Product_Model__c = 'PC130T',
            Dummy_Product_Description__c = 'PHAKIC-TORIC',
            Dummy_ID_Code__c = 'D037',
            //Spherical_power__c = '5.0',
           // Hydrophilic_Size__c = '120.0',
            Business_Vertical__c = 'OPHTHALMOLOGY',
            Category__c = 'REFRACTIVE PRODUCTS',
            Sub_Category__c = 'Eyecryl PHAKIC TORIC',
            Brand__c = 'Eyecryl Phakic Toric',
            Group_Name__c = '(PC 130T)',
            Cylinder_Power__c = '0.2',
            Axis__c = '120.0',
            Diaptor__c = '16.0',
            Priority__c = 1 // Set an appropriate priority level
        );
        
        insert sampleProduct2;
        
          // Create and insert custom setting records
        Sample_Request_Module_labels__c customSetting1 = new Sample_Request_Module_labels__c(
            Name = 'en_US',
            SAP_Code__c = '123456',
            Phakic_Rating__c = 'Phakic Rating',
            CE_CIS_Rating__c = 'CECIS Phakic Rating',
            Phone_Number__c = '+91 9876543210',
            Email__c = 'customer@example.com',
            Account_Name__c = 'XYZ Enterprises',
            Please_select_the_customer_type__c = 'Individual',
            Failed_to_save_data__c = 'Failed to save data',
            Sample_Request_Submitted_successfully__c = 'Sample Request Submitted successfully!',
            SAP_code_not_found_for_this_customer_Pl__c = 'SAP code not found for this customer. Please initiate the customer, then proceed',
            Order_Has_Been_Cancelled__c = 'Order Has Been Cancelled',
            Close__c = 'Close',
            sap_or_zip_code__c = '12345',
            Phone__c = '+91 9876543210'
        );
        
        insert customSetting1;
        
        System.debug('Sample Request Product Created: ' + sampleProduct.Id);
        
        Map<String, String> rmarkandsapcode = new Map<String, String>{'sapCode' => '1200345','remark' => 'Test'};
            // Create a sample finalData list to simulate the data for insertion
        List<Map<String, String>> finalData = new List<Map<String, String>>{
            new Map<String, String>{
                'productName' => 'PHAKIC-TORIC',
                'productModel' => 'PC130T',
                'sphericalPower' => '5.0',
                'axisAngle' => '120.0',
                'cylindricalPower' => '0.2',
                'commercialQuantity' => '100',
                'diaptor' => '16.'
            }
            
        };
             List<Map<String, String>> finalData2 = new List<Map<String, String>>{
                new Map<String, String>{
                    'productName' => 'PHAKIC-TORIC',
                        'productModel' => 'PC130T',
                        'sphericalPower' => '',
                        'axisAngle' => '120.0',
                        'cylindricalPower' => '0.2',
                        'commercialQuantity' => '100',
                        'diaptor' => '16.0',
                        'remark' =>'test'
                        }
                
            };
        

      List<String> sttraccmap =new List<String>{accObj.Id};
          List<String> sttraccmaplead =new List<String>{lea.Id};
        
        // Test the method with the Lead record ID
        Test.startTest();
        Map<String, Object> response = SampleRequestLWCcontroller.fetchSampleRequestProduct(lea.Id);
        Map<String, Object> responseacc = SampleRequestLWCcontroller.fetchSampleRequestProduct(accObj.Id);
        Map<string, Object> rzsponse = SampleRequestLWCcontroller.fetchmultiplecustomerSampleRequestProduct();
         Map<string, Object> rezsponselead = SampleRequestLWCcontroller.fetchDropdownOptions(lea.Id,sampleProduct.Dummy_Product_Description__c,sampleProduct.Product_Model__c,sampleProduct.Spherical_power__c,sampleProduct.Cylinder_Power__c,sampleProduct.Axis__c,sampleProduct.Diaptor__c);
         Map<string, Object> rezsponseaccount = SampleRequestLWCcontroller.fetchDropdownOptions(accObj.Id,sampleProduct.Dummy_Product_Description__c,sampleProduct.Product_Model__c,sampleProduct.Spherical_power__c,sampleProduct.Cylinder_Power__c,sampleProduct.Axis__c,sampleProduct.Diaptor__c);
         Map<string, Object> rezsponsedropdown = SampleRequestLWCcontroller.fetchDropdownOptionsformultiplecustomer(lea.country__c,sampleProduct.Dummy_Product_Description__c,sampleProduct.Product_Model__c,sampleProduct.Spherical_power__c,sampleProduct.Cylinder_Power__c,sampleProduct.Axis__c,sampleProduct.Diaptor__c);
         Map<string, Object> rezsponselabel = SampleRequestLWCcontroller.getcustomerdata(lea.country__c);
        string rezsponsela = SampleRequestLWCcontroller.getCountries();
        Sample_Request_Module_labels__c rsponse = SampleRequestLWCcontroller.getCustomLabels();
        string rsponslea = SampleRequestLWCcontroller.saveSampleRequestDataforsinglecustomer(finalData, lea.Id,rmarkandsapcode);
        string rsponsacc = SampleRequestLWCcontroller.saveSampleRequestDataforsinglecustomer(finalData, accObj.Id,rmarkandsapcode);
        string ezsponselabelrsponsacc = SampleRequestLWCcontroller.saveSampleRequestDataformultiplecustomer(finalData2,sttraccmap,sttraccmaplead);



        
        Test.stopTest();
        
       
    }
       
  
}