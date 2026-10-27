@isTest
global class OrderCreationSapCalloutMock implements HttpCalloutMock{
  global HTTPResponse respond(HTTPRequest req){
    // Create a new HTTPResponse object.
    HttpResponse res = new HttpResponse();
    // Set the response status code.
    res.setHeader('Content-Type', 'text/plain');
    // Set the response body with the JSON you want to mock.
    res.setBody('{"Record":[{"statuscode":1,"OrderNumber":3110177765,"message":"Order Created Successfully","SplitCondition":"12HDL0297P21.00"}]}');
    res.setStatusCode(200);

    return res;
  }

}