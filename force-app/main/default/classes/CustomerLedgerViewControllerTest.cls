@istest
public class CustomerLedgerViewControllerTest {

    @istest
    public static void test1(){

        Test.startTest();
        CustomerLedgerViewController.getAccounts(0,10, 1, '');
        CustomerLedgerViewController.getSearchAccountsWithText('Biotech');
        Test.stopTest();
    }

    @isTest static void testingCalloutMethod() {
        insert new SAP_Creds__c(Name ='SAP_LedgerPDFData', Username__c = 'POSUPPORT', Password__c = 'Complex@321', Endpoint__c = 'http://103.231.40.47:50000/RESTAdapter/salesforce/transactional/GetCustomerGLPDF');
        String requestData = '[{"Name":"demo23","Id":"001Bl00000ECrLVIA1","fromDate":"2024-05-01","toDate":"2024-04-02","sapcode":"1200021","companycode":"1000"}]';

        // setting mock callout
        Test.setMock(HttpCalloutMock.class, new CustomerLedgerViewControllerMockResponse());
        List<Map<String,String>> selectedData = (List<Map<String,String>>)JSON.deserialize(requestData,List<Map<String,String>>.class);
        Test.startTest();
        //calling the method
        List<CustomerLedgerViewController.CustomerData> res = CustomerLedgerViewController.getBase64String(selectedData);
        Test.stopTest();

        //checking the response
        System.assertEquals(1, res[0].Status);

        String responseMessage = res[0].message;
        String expectedMessage = 'Invoice PDF found and added in response';
        System.assertEquals(expectedMessage, responseMessage);

        String responseString = res[0].PDFData;
        String expectedString = 'hereIsBase64StringForPDF';
        System.assertEquals(expectedString, responseString);

    }
}