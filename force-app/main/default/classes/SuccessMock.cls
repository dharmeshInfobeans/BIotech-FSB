public class SuccessMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        
        res.setBody(
            '{"Response":[{"Status":"1","Message":"Success","CustomerSchemeID":"CS-1001"}]}'
        );
        
        return res;
    }
}