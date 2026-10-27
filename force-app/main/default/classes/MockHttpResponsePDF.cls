@isTest
global class MockHttpResponsePDF implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        res.setBody(
            '{ "Response": { ' +
            '"Message": "Success", ' +
            '"PDFData": "dGVzdA==" ' +  // base64 (VERY IMPORTANT)
            '} }'
        );

        return res;
    }
}