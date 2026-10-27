@isTest
public class MockHttpResponseGenerator implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"Status": 1, "Message": "Data Synced Successfully"}');
        return res;
    }
}