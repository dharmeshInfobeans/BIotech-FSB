@IsTest
global class FreightSplitOrderCalloutErrorMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
   
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200); // SAP returns 200 even for business errors

        res.setBody(
            '{' +
                '"root":[ {' +
                    '"Statuscode": "0 ",' +
                    '"Plant": "",' +
                    '"Message": "Material Number E10425 is not maintained in ZDMAS_EXP"' +
                '}]' +
            '}'
        );

        return res;

    }
}