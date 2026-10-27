public with sharing class ZohoRefreshService {

    public static void refreshAccessToken() {

        Zoho_Settings__c cs = Zoho_Settings__c.getOrgDefaults();

        String endpoint = 'https://accounts.zoho.in/oauth/v2/token'+'?refresh_token=' + EncodingUtil.urlEncode(cs.Refresh_Token__c,'UTF-8')+'&client_id='+ EncodingUtil.urlEncode(cs.Client_Id__c,'UTF-8')+'&client_secret=' + EncodingUtil.urlEncode(cs.Client_Secret__c,'UTF-8')+ '&grant_type=refresh_token';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');

        HttpResponse res = new Http().send(req);
        
        System.debug('Status Code = ' + res.getStatusCode());
        System.debug('Response = ' + res.getBody());

        System.debug(res.getBody());

        Map<String,Object> result = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());

        cs.Access_Token__c = (String)result.get('access_token');

        Integer expiresIn = Integer.valueOf(String.valueOf(result.get('expires_in')));

        cs.Access_Token_Expiry__c = System.now().addSeconds(expiresIn);

        update cs;
        
        System.debug('Updated Token = ' + cs.Access_Token__c);
        System.debug('Updated Expiry = ' + cs.Access_Token_Expiry__c);

    }
}