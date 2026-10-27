@isTest
public class GenerateInvoicePDFControllerMockResponse implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {
        //checking outgoing data
        //System.assertEquals('http://103.231.40.158:50000/RESTAdapter/salesforce/transactional/SF_InvoicePDFData', req.getEndpoint(), 'EndPoint Correct');
        //System.assertEquals('POST', req.getMethod(), 'Method Correct');
        String header = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf('piuser:Welcome@123'));
        //System.assertEquals(header, req.getHeader('Authorization'), 'Header Authorization Correct');
        //System.assertEquals(header, req.getHeader('Content-Type'), 'Header Content-Type Correct');
        //System.assertEquals(header, req.getHeader('Content-Length'), 'Header Content-Length Correct');
       // System.assertEquals('{\"Records\":[{\"SalesForce_Order_Number\":\"OSF00010003\",\"SAP_Order_Number\":\"3130006843\",\"Invoice_Number\":\"90028838\"}]}', req.getBody(), 'Body Correct');

        //creating fake response
        HttpResponse res = new HttpResponse();

        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"Records":{"Status_Code":1,"Message":"Invoice PDF found and added in response","Base64":"hereIsBase64StringForPDF"}}');
        res.setStatusCode(200);
        
        return res;
    }
}