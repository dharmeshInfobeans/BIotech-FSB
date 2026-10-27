@isTest
public class SchemeRestServiceTest {
    
    @isTest
    static void testDoPost_Insert() {
        
        SchemeRestService.Scheme schemeObj = new SchemeRestService.Scheme();
        schemeObj.SCHEMENAME = 'Test Scheme';
        schemeObj.SCHEMEDESC = 'Test Desc';
        schemeObj.TENURE = '12 Months';
        schemeObj.PAYTERMS = 'Monthly';
        schemeObj.TOTBUSINESS = '10000';
        schemeObj.PURUNITCOMM = 'Yes';
        schemeObj.MINQTY = 10;
        schemeObj.CREDITNOTE = 'CN001';
        schemeObj.TOTALQTYFLG = 1;
        schemeObj.CREDITPER = 5.5;
        schemeObj.ADDCN = '2';
        schemeObj.TOTALAMT = 1000;
        schemeObj.VALIDUPTO = Date.today().addDays(30);
        schemeObj.ISDELETED = false;
        schemeObj.SCHEMENo = 'SCH001';
        schemeObj.Country = 'India';
        
        SchemeRestService.SchemeLinetem lineItem = new SchemeRestService.SchemeLinetem();
        lineItem.SCHEMENO = 'SCH001';
        lineItem.PRODUCTCODE = 'P001';
        lineItem.PRODUCTDESC = 'Product 1';
        lineItem.MINQTY = 5;
        lineItem.REGPRICE = 100;
        lineItem.CREDITNOTE = 'CN-L1';
        lineItem.NETPRICE = 95;
        lineItem.CREDITPER = 5;
        lineItem.CRNOTPLGST = 'Yes';
        lineItem.ADDCN = 1;
        lineItem.BENEFIT = 'Benefit 1';
        lineItem.ISDELETED = false;
        
        schemeObj.schemeLinetems = new List<SchemeRestService.SchemeLinetem>{ lineItem };
            
            List<SchemeRestService.Scheme> schemeList = new List<SchemeRestService.Scheme>{ schemeObj };
                
                String requestBody = JSON.serialize(schemeList);
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/insertSchemes/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestResponse res = new RestResponse();
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        SchemeRestService.ApiResponse response = SchemeRestService.doPost();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Success', response.status);
        
        System.assertEquals(1, [
            SELECT count() FROM Scheme_Information__c WHERE Scheme_Number__c = 'SCH001'
        ]);
        
        System.assertEquals(1, [
            SELECT count() FROM Scheme_Line_Item__c WHERE Product_Code__c = 'P001'
        ]);
    }
}