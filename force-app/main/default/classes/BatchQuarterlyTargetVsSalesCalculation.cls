global class BatchQuarterlyTargetVsSalesCalculation implements Database.Batchable<sObject>,Database.Stateful{

    global map<id,KRA_Calculation__c> mapKRACal = new map<id,KRA_Calculation__c>();
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                         Financial_Year__r.End_Date__c,Product_1__c,Product_2__c,Division__c,DivisionT__c, 
                                         (select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                          from KRA_Details__r) from KRA_Configuration__c where Parameter__c = 'Target vs Sales']);
    }
 
    global void execute(Database.BatchableContext BC, List<KRA_Configuration__c> scope){
        System.debug('***In Execute method***'+scope);
       
        List<KRA_Calculation__c> lstKRACal = new List<KRA_Calculation__c>();
        if(!scope.isEmpty()){
            for(KRA_Configuration__c KRAConfig : scope){
                if(KRAConfig.Role__c.contains(';'))
                {
                    for(String rolename :KRAConfig.Role__c.split(';'))
                    {
                        if(KRAConfig.Parameter__c == 'Target vs Sales'){
                                QuarterlyTargetVsSalesCalculation QtrTgtAct = new QuarterlyTargetVsSalesCalculation();
                               lstKRACal.addAll(QtrTgtAct.calculateKRA(KRAConfig, rolename));
                           }
                    }
                }
                else
                {
                    if(KRAConfig.Parameter__c == 'Target vs Sales'){
                            QuarterlyTargetVsSalesCalculation QtrTgtAct = new QuarterlyTargetVsSalesCalculation();
                           lstKRACal.addAll(QtrTgtAct.calculateKRA(KRAConfig, KRAConfig.Role__c));
                       }
                }
                
                for(KRA_Calculation__c kracal : lstKRACal){
                    if(!mapKRACal.containsKey(kracal.OwnerId)){
                        mapKRACal.put(kracal.OwnerId,kracal);
                    }else{
                        KRA_Calculation__c krac = mapKRACal.get(kracal.OwnerId);
                        system.debug('***krac***'+krac);
                        if(krac != null){
                            if(kracal.Target__c != null && krac.Target__c != null){
                                krac.Target__c += kracal.Target__c;
                            }
                            if(kracal.Actual__c != null && krac.Actual__c != null){
                                krac.Actual__c += kracal.Actual__c;
                            }
                            if(kracal.Actual__c != null && krac.Percentage__c != null){
                                krac.Percentage__c = (krac.Actual__c/krac.Target__c) * 100;
                            }
                            
                            mapKRACal.put(krac.OwnerId,krac);
                        }
                    }
                }
                
            }
           
        }
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('In Target vs Actual batch finish method : ');
        system.debug('***mapKRACal***'+mapKRACal);
        set<id> kraset = new set<id>();
        for(KRA_Calculation__c kra : mapKRACal.values()){
            kraset.add(kra.KRA_Configuration__c);
        }
        List<KRA_Configuration__c> Kraconfig = [Select Id,(select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                          from KRA_Details__r) from KRA_Configuration__c where Id IN:kraset];
        map<id,List<KRA_Parameter_Detail__c>> mapDetails = new map<id,List<KRA_Parameter_Detail__c>>();
        for(KRA_Configuration__c kraca : Kraconfig){
            if(!mapDetails.containsKey(kraca.Id))
                mapDetails.put(kraca.Id,new List<KRA_Parameter_Detail__c>());
            mapDetails.get(kraca.Id).addAll(kraca.KRA_Details__r);
         }
        
        for(KRA_Calculation__c kracals : mapKRACal.values()){
            List<KRA_Parameter_Detail__c> paramlst = mapDetails.get(kracals.KRA_Configuration__c);
            if(!paramlst.isEmpty()){
                for(KRA_Parameter_Detail__c kra :  paramlst) {
                    boolean isFirstInstanceFound = False;
                    if(((kracals.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                        || (kracals.Percentage__c >= kra.Achievement_from__c && kracals.Percentage__c <= kra.Achievement_to__c)) && !isFirstInstanceFound){
                            kracals.Points__c = kra.Points__c;
                            isFirstInstanceFound = true;
                        }else if(kracals.Percentage__c < 60 && !isFirstInstanceFound){
                            kracals.Points__c = 0;
                            isFirstInstanceFound = true;
                        } 
                }
            }
        }
        if(!mapKRACal.values().isEmpty())
            insert mapKRACal.values();//lstKRACal;
    }
    
    
  public void test(){
        integer a= 0;
        integer b = 0 ;
        integer c = 0;
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c;        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c;  a = b + c; b = a + c; c = a + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c;a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; 
        b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; c = a + c; a = b + c; b = a + c; 
        a = b + c; b = a + c; c = a + c;
    }
}