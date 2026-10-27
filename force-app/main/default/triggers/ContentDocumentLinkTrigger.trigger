trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {


   Schema.DescribeSObjectResult r = Account.sObjectType.getDescribe();
    System.debug('r'+r);
    String keyPrefix = r.getKeyPrefix();
    System.debug('keyPrefix'+keyPrefix);
      for(ContentDocumentLink cdl:trigger.new){
        if((String.valueOf(cdl.LinkedEntityId)).startsWith(keyPrefix)){
            
          cdl.ShareType = 'I';
          cdl.Visibility = 'AllUsers';
          } 
       }
    }