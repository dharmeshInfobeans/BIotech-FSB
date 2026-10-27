@isTest
public class MockFailedHttpResponseGenerator implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"Status": -1, "Message": "Data Synced Failed:- akjdhsgfsdjhf$$ jvdkaxDFasdss$$jasdasjdgasj$$"}');
        return res;
    }
}