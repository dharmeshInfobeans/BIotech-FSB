@IsTest
global class FreightSplitOrderCalloutMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        res.setBody(
            '{ "root": [ ' +
            '{ "Statuscode":"200",' +
            '"OrderID":"SAP123",' +
            '"OrderProductsId":"'+Test.getStandardPricebookId()+'",' +
            '"Plant":"8100",' +
            '"SplitCondition":"AUTO" } ] }'
        );
        return res;
    }
}