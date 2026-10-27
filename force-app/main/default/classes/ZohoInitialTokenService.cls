public with sharing class ZohoInitialTokenService {
    
    public static void generateTokens() {
        
        Zoho_Settings__c cs = Zoho_Settings__c.getOrgDefaults();
        
        System.debug('Record = ' + cs);
        System.debug('Client Id = ' + cs.Client_Id__c);
        System.debug('Client Secret = ' + cs.Client_Secret__c);
        System.debug('Authorization Code = ' + cs.Authorization_Code__c);
        
        String endpoint ='https://accounts.zoho.in/oauth/v2/token'+ '?grant_type=authorization_code'+ '&client_id=' + EncodingUtil.urlEncode(cs.Client_Id__c,'UTF-8')+ '&client_secret=' + EncodingUtil.urlEncode(cs.Client_Secret__c,'UTF-8')+ '&code=' + EncodingUtil.urlEncode(cs.Authorization_Code__c,'UTF-8');
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        
        HttpResponse res = new Http().send(req);
        
        System.debug(res.getBody());
        
        Map<String,Object> result = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
        
        cs.Access_Token__c = (String)result.get('access_token');
        
        cs.Refresh_Token__c = (String)result.get('refresh_token');
        
        Integer expiresIn = Integer.valueOf(String.valueOf(result.get('expires_in')));
        
        cs.Access_Token_Expiry__c = System.now().addSeconds(expiresIn);
        
        update cs;
    }
}