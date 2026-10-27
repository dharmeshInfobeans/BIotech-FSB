/************************************************************************
Author : Prashant Rana
Description : This is mock test class for DCR Callout class
Date : 2019-04-09
**************************************************************************/
@isTest
global class DCRCallOutMockTest implements HttpCalloutMock{

    global HTTPResponse respond(HTTPRequest req) {
        
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{example": "test"}');
        res.setStatusCode(200);
        return res;
    } 
    
}