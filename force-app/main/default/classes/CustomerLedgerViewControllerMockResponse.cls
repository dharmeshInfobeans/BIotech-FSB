@isTest
public class CustomerLedgerViewControllerMockResponse implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {
        //checking outgoing data
        System.assertEquals('http://103.231.40.47:50000/RESTAdapter/salesforce/transactional/GetCustomerGLPDF', req.getEndpoint(), 'EndPoint Correct');
        System.assertEquals('GET', req.getMethod(), 'Method Correct');
        String header = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf('POSUPPORT:Complex@321'));
        System.assertEquals(header, req.getHeader('Authorization'), 'Header Authorization Correct');
        //System.assertEquals(header, req.getHeader('Content-Type'), 'Header Content-Type Correct');
        //System.assertEquals(header, req.getHeader('Content-Length'), 'Header Content-Length Correct');
        System.assertEquals('{"Records": [{"PostingDateTo":"02.04.2024","PostingDateFrom":"01.05.2024","IsRegularCustomer":"","IsEquipmentCustomer":"","Customer":"1200021","CompanyCode":"1000","AdditionalField5":null,"AdditionalField4":null,"AdditionalField3":null,"AdditionalField2":null,"AdditionalField1":null}]}', req.getBody(), 'Body Correct');

        //creating fake response
        HttpResponse res = new HttpResponse();

        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"Record":[{"Status":1,"Message":"Invoice PDF found and added in response","PDFData":"hereIsBase64StringForPDF"}]}');
        res.setStatusCode(200);

        return res;
    }
}