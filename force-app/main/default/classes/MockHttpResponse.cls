@isTest
public class MockHttpResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody('{"Record": [{"statuscode": "1", "message": "Order Number - 123456"}]}');
        return res;
    }
}