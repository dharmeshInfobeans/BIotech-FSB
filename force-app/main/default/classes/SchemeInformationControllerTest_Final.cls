@isTest
public class SchemeInformationControllerTest_Final {
    
    class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{ "d": { "BundleCustomer":"YES","to_Children": { "results": [ { "ChildCustomer": "C001" } ] } } }');
            return res;
        }
    }
    
    class MockFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            return res;
        }
    }
    
    static void setupData() {
        
        insert new MOU_Integration__c(
            Name = 'parenttochildsyncingwithparam',
            End_Point_URL__c = 'https://test.com(\'\')',
            Username__c = 'test',
            Password__c = 'test'
        );
        
        insert new MOU_Scheme_Back_Date_Provision_Setting__c(
            Name = 'INDIA',
            Number_Of_Months__c = 3
        );
    }
    
    static Account createParent() {
        Account acc = new Account(
            Name='Parent',
            BillingCountry='India',
            SAP_Code__c='P001'
        );
        insert acc;
        return acc;
    }
    
    static Account createChild(Id parentId) {
        Account acc = new Account(
            Name='Child',
            BillingCountry='India',
            SAP_Code__c='C001',
            ParentId=parentId
        );
        insert acc;
        return acc;
    }
    
    @isTest
    static void testGetInitialData() {
        
        setupData();
        Account parent = createParent();
        
        insert new Scheme_Information__c(
            Name='Scheme',
            Country__c='India',
            Valid_Upto__c=System.today().addDays(5)
        );
        
        Test.startTest();
        SchemeInformationController.getInitialData(parent.Id);
        Test.stopTest();
        
        parent.BillingCountry = null;
        update parent;
        
        SchemeInformationController.getInitialData(parent.Id);
    }
    
    @isTest
    static void testCreateSchemeFull() {
        
        setupData();
        Account parent = createParent();
        Account child = createChild(parent.Id);
        
        List<Object> jsonList = new List<Object>{
            new Map<String,Object>{
                'Add_On__c' => '5',
                    'Country__c' => 'India',
                    'Credit_Note__c' => 'CN001',
                    'Credit_Percentage__c' => '10',
                    'Is_Deleted__c' => 'false',
                    'Min_Qty__c' => '2',
                    'Pay_Terms__c' => '30 Days',
                    'PUR_Unit_Comm__c' => 'Test',
                    'Scheme_Desc__c' => 'Test Desc',
                    'Scheme_Number__c' => 'SCH200',
                    'Name' => 'Scheme Name',
                    'Tenure__c' => '12',
                    'TOT_Business__c' => '100000',
                    'Total_Amount__c' => '5000',
                    'Total_Qty_Flg__c' => 'Yes',
                    'Valid_Upto__c' => String.valueOf(System.today().addDays(5)),
                    
                    'Scheme_Line_Items__r' => new List<Object>{
                        new Map<String,Object>{
                            'Scheme_No__c' => 'SCH200',
                                'Add_On__c' => '1',
                                'Benifit__c' => 'Benefit',
                                'CR_Note_PL_GST__c' => 'GST',
                                'Credit_Note__c' => 'CN1',
                                'Credit_Percentage__c' => '5',
                                'Is_Deleted__c' => 'false',
                                'Min_Qty__c' => '1',
                                'Net_Price__c' => '100',
                                'Product_Code__c' => 'P001',
                                'Product_Description__c' => 'Product',
                                'Reg_Price__c' => '120'
                                }
                    }
            }
        };
            
            List<Object> accData = new List<Object>{
                new Map<String,Object>{
                    'Id'=>parent.Id,
                        'Start_Date__c'=>String.valueOf(System.today()),
                        'End_Date__c'=>String.valueOf(System.today().addDays(5))
                        }
            };
                
                Test.startTest();
        
        String res = SchemeInformationController.createSchemeRequestAndLineItems(
            jsonList,
            accData,
            new List<String>{parent.Id, child.Id}
        );
        
        Test.stopTest();
        
        String res2 = SchemeInformationController.createSchemeRequestAndLineItems(
            jsonList,
            null,
            null
        );
        
        System.assertEquals('No Accounts Found', res2);
    }
    
    @isTest
    static void testCalloutSuccess() {
        
        setupData();
        Account parent = createParent();
        createChild(parent.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        
        Test.startTest();
        SchemeInformationController.getAccountWithChildren(parent.Id, 'SCH200');
        SchemeInformationController.getParentAndChildSchemes(parent.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testCalloutFailure() {
        
        setupData();
        
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        
        Test.startTest();
        SchemeInformationController.getParentCustomer('P001');
        Test.stopTest();
    }
    
    @isTest
    static void testCheckSchemeData() {
        
        setupData();
        Account parent = createParent();
        Account child = createChild(parent.Id);
        
        insert new Scheme_Request__c(
            Account__c=parent.Id,
            Scheme_Number__c='SCH300',
            Approval_Status__c='Approved',
            End_Date__c=System.today().addDays(5)
        );
        
        List<Object> parentData = new List<Object>{
            new Map<String,Object>{
                'Id'=>parent.Id,
                    'Start_Date__c'=>String.valueOf(System.today())
                    }
        };
            
            Test.startTest();
        SchemeInformationController.checkschemedata(
            parentData,
            new List<String>{parent.Id},
            'SCH300'
        );
        Test.stopTest();
        
        SchemeInformationController.checkschemedata(
            parentData,
            new List<String>{parent.Id},
            'NEW'
        );
        
        List<Object> childData = new List<Object>{
            new Map<String,Object>{
                'Id'=>child.Id,
                    'Start_Date__c'=>String.valueOf(System.today())
                    }
        };
            
            SchemeInformationController.checkschemedata(childData, null, 'NEW');
    }
    
    @isTest
    static void testApiLog() {
        
        Test.startTest();
        SchemeInformationController.createApiErrorLog(
            'Test','Class',400,'Fail','msg','req','res'
        );
        Test.stopTest();
    }
    @isTest
    static void testCreateSchemeRequestAndLineItems_FULL() {
        
        Account parentAcc = new Account(
            Name = 'Parent Account',
            BillingCountry = 'India'
        );
        insert parentAcc;
        
        Account childAcc = new Account(
            Name = 'Child Account',
            ParentId = parentAcc.Id,
            BillingCountry = 'India'
        );
        insert childAcc;
        
        List<Object> accountdata = new List<Object>();
        
        Map<Object, Object> accMap = new Map<Object, Object>{
            'Id' => childAcc.Id,
                'Start_Date__c' => String.valueOf(Date.today()),
                'End_Date__c' => String.valueOf(Date.today().addDays(30))
                };
                    
                    accountdata.add(accMap);
        
        List<String> accIds = new List<String>{
            parentAcc.Id,
                childAcc.Id
                };
                    
                    List<Object> lineItems = new List<Object>();
        
        Map<Object, Object> lineItemMap = new Map<Object, Object>{
            'Scheme_No__c' => 'SCH001',
                'Add_On__c' => '1',
                'Benifit__c' => 'Test Benefit',
                'CR_Note_PL_GST__c' => 'GST',
                'Credit_Note__c' => 'CN',
                'Credit_Percentage__c' => '5',
                'Is_Deleted__c' => 'false',
                'Min_Qty__c' => '10',
                'Net_Price__c' => '100',
                'Product_Code__c' => 'P001',
                'Product_Description__c' => 'Test Product',
                'Reg_Price__c' => '120'
                };
                    
                    lineItems.add(lineItemMap);
        
        List<Object> jsonObj = new List<Object>();
        
        Map<Object, Object> mainMap = new Map<Object, Object>{
            'Add_On__c' => '1',
                'Country__c' => 'india',
                'Credit_Note__c' => 'CN001',
                'Credit_Percentage__c' => '10',
                'Is_Deleted__c' => 'false',
                'Min_Qty__c' => '5',
                'Pay_Terms__c' => '30 Days',
                'PUR_Unit_Comm__c' => 'Unit',
                'Scheme_Desc__c' => 'Test Scheme Desc',
                'Scheme_Number__c' => 'SCH001',
                'Name' => 'Test Scheme',
                'Tenure__c' => '12',
                'TOT_Business__c' => '1000',
                'Total_Amount__c' => '5000',
                'Total_Qty_Flg__c' => 'Y',
                'Valid_Upto__c' => String.valueOf(Date.today().addDays(10)),
                'Scheme_Line_Items__r' => lineItems
                };
                    
                    jsonObj.add(mainMap);
        
        Test.startTest();
        
        String result = SchemeInformationController.createSchemeRequestAndLineItems(
            jsonObj,
            accountdata,
            accIds
        );
        
        Test.stopTest();
        
        System.assertEquals('success', result);
        
        List<Scheme_Request__c> reqList = [SELECT Id FROM Scheme_Request__c];
        System.assert(reqList.size() > 0);
        
        List<Scheme_Request_Line_Item__c> lineList = [SELECT Id FROM Scheme_Request_Line_Item__c];
        System.assert(lineList.size() > 0);
    }
}