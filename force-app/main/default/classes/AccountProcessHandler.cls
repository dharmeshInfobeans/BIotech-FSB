global with sharing class AccountProcessHandler {
    
    @InvocableMethod(label='Create Monthly Plan Records' description='When Account gets activated, this method will create 12 MonthlyPlan records for each account')
    global static void createMonthlyPlanRecords(List<MonthlyPlanCreationRequest> mpcrRequests) {
        For(MonthlyPlanCreationRequest mpcr : mpcrRequests ){
            if(mpcr.isFromBatch){
                createMonthlyPlanRecord(mpcr,true);
            }else{
                createMonthlyPlanRecord(mpcr,false); 
            }
        }    
    }
    
    public static void createMonthlyPlanRecord(MonthlyPlanCreationRequest mpcrRequest,Boolean fromBatch){
        System.debug('In ZZZ AccountProcessHandler.cls-->createMonthlyPlanRecord_M--> Entered!!!!');
        //String fiscalYear = [SELECT FiscalYearSettings.Name FROM Period WHERE Type = 'Year' AND StartDate <= TODAY AND EndDate >= TODAY].FiscalYearSettings.Name;
        
        List<Account> accWithExistingMP = [ Select Id,SAP_Code__c,recordtypeid,(Select Id from Monthly_Plans__r)
                                           FROM Account
                                           Where Id = :mpcrRequest.accountId
                                           LIMIT 1
                                          ];
                                          
        String recordtypename = Schema.SObjectType.Account.getRecordTypeInfosById().get(accWithExistingMP[0].recordtypeid).getDeveloperName();
        String recordname=(( recordtypename=='Distributor' || recordtypename=='Doctor_D' || recordtypename=='Ophthalmic_Vision' || recordtypename=='Ortho_Dermal') ? 'Dom/Int' : (( recordtypename=='Distributor_T' || recordtypename=='Doctor_T')  ? 'Turkey' : 'NA'));
        
        Period currPeriod = [SELECT FiscalYearSettings.Name,FiscalYearSettings.EndDate,FiscalYearSettings.StartDate FROM Period WHERE Type = 'Year' AND StartDate <= TODAY AND EndDate >= TODAY LIMIT 1];
        String  fiscalYear            = currPeriod.FiscalYearSettings.Name; //Fiscal Year End
        String  prevFiscalYear        = String.valueOf(Integer.valueOf(fiscalYear) - 1);
        Integer fiscalStartMonthValue = currPeriod.FiscalYearSettings.StartDate.month();
        Integer fiscalEndMonthValue   = currPeriod.FiscalYearSettings.EndDate.month();
        Integer fiscalStartYearValue  = currPeriod.FiscalYearSettings.StartDate.year();
        Integer fiscalEndYearValue    = currPeriod.FiscalYearSettings.EndDate.year();
        Integer currentMonthValue = System.today().month();
        Integer currentYearValue  = System.today().year();
        
        List<Monthly_Plan__c> monthlyPlansList =  new List<Monthly_Plan__c>();
        List<Monthly_Plan__c> monthlyPlansListTur =  new List<Monthly_Plan__c>();
        
        if(!fromBatch){
            if(!accWithExistingMP.isEmpty()){
                Set<Monthly_Plan__c> existingMP = new Set<Monthly_Plan__c>(accWithExistingMP[0].Monthly_Plans__r);
                if(!(existingMP.size() > 0)){ Integer index=0;
                    for(Integer i=0; i < mpcrRequest.numberOfMonthlyPlanRecords; i++ ){
                        Monthly_Plan__c mp = new Monthly_Plan__c();
                        mp.Account__c = mpcrRequest.accountId;
                        mp.Stage__c   = 'Open';
                        mp.Financial_Year__c = String.valueOf(recordname=='Turkey'? String.valueOf(System.today().year()) : (recordname=='Dom/Int' ? fiscalYear : 'NA')); 

                        if(i==9 || i==10 || i==11)
                        mp.Year__c= String.valueOf(recordname=='Turkey'?String.valueOf(System.today().year()) : (recordname=='Dom/Int' ? String.valueOf(fiscalEndYearValue) : 'NA')); 
                        else
                        mp.Year__c= String.valueOf(System.today().year());                                       
                                    
                                       
                        Switch on i{
                            when 9 {
                               mp.Name = 'JAN-'+mp.Year__c +'-'+accWithExistingMP [0].SAP_Code__c+'-Monthly Plan';                                                  
                               mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Jan'  +mp.Year__c ;
                               mp.Month__c   = 'Jan';
                               monthlyPlansList.add(mp);
                            }
                            when 10 {
                                mp.Name = 'FEB-'+ mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Feb' +mp.Year__c ;
                                mp.Month__c   = 'Feb';                            
                                monthlyPlansList.add(mp);
                            }
                            when 11 {
                                mp.Name = 'MAR-'+mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Mar'  +mp.Year__c ;
                                mp.Month__c   = 'Mar'; 
                                monthlyPlansList.add(mp);
                            }
                            when 0 {
                                mp.Name = 'APR-'+ mp.Year__c+'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Apr'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Apr'; 
                                monthlyPlansList.add(mp);
                            }
                            when 1 {
                                mp.Name = 'MAY-'+ mp.Year__c+'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'May'+String.valueOf(System.today().year());
                                mp.Month__c   = 'May'; 
                                monthlyPlansList.add(mp);
                            }
                            when 2 {
                                mp.Name = 'JUN-'+ mp.Year__c+'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Jun'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Jun';
                                monthlyPlansList.add(mp);
                            }
                            when 3 {
                                mp.Name = 'JUL-'+ mp.Year__c+'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                               mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Jul'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Jul'; 
                                monthlyPlansList.add(mp);
                            }
                            when 4 {
                                mp.Name = 'AUG-'+ mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Aug'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Aug'; 
                                monthlyPlansList.add(mp);
                            }
                            when 5 {
                                mp.Name = 'SEP-'+ mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Sep'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Sep';
                                monthlyPlansList.add(mp);
                            }
                            when 6 {
                                mp.Name = 'OCT-'+ mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Oct'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Oct'; 
                                monthlyPlansList.add(mp);
                            }
                            when 7 {
                                mp.Name = 'NOV-'+  mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Nov'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Nov';
                                monthlyPlansList.add(mp); 
                            }
                            when 8 {
                                mp.Name = 'DEC-'+ mp.Year__c +'-'+accWithExistingMP[0].SAP_Code__c+'-Monthly Plan';
                                mp.MPUID__c   = accWithExistingMP[0].SAP_Code__c+'Dec'+String.valueOf(System.today().year());
                                mp.Month__c   = 'Dec';   
                                monthlyPlansList.add(mp);
                            } 
                            when else{
                                
                            }
                        }
                        
                    }
                    
                    if(monthlyPlansList.size()>0)  
                       Database.SaveResult[] srList = Database.insert(monthlyPlansList,false);                  
                   
                    //System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->DML Result-->'+srList);
                    
                }  // If ends.......
            }
        }else{
            
            if(mpcrRequest.isFromBatch){
               // System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->Inside Batch !!!!!!!!!!!!');
                //System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->Batch-->CURR_FISCALSTARTYEAR-->'+fiscalStartYearValue);
                //System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->Batch-->CURR_FISCALENDYEAR-->'+fiscalEndYearValue);
                
                for(Integer j = 0; j < mpcrRequest.mPlanList.size(); j++ ){
                      // System.debug('Constants.MONTH_VALUE_MAP.get'+j+'  VAL-->'+Constants.MONTH_VALUE_MAP.get(j));
                      // System.debug('mpcrRequest.mPlanList['+j+'].Month__c VAL-->'+mpcrRequest.mPlanList[j].Month__c);
                      // System.debug('mpcrRequest.mPlanList['+j+'].Financial_Year__c VAL-->'+mpcrRequest.mPlanList[j].Financial_Year__c);
                      // System.debug('mpcrRequest.previousFiscalYear VAL-->'+mpcrRequest.previousFiscalYear);
                       
                    if((Constants.MONTH_VALUE_MAP.get(j) == mpcrRequest.mPlanList[j].Month__c) && (mpcrRequest.mPlanList[j].Financial_Year__c == mpcrRequest.previousFiscalYear) ){
                      //  system.debug('INSIDE IF!!!!!!!!!!!!!!!!');
                        Monthly_Plan__c mp = new Monthly_Plan__c();
                        mp.Last_Year_Monthly_Plan__c = mpcrRequest.mPlanList[j].Id;
                        mp.Account__c = mpcrRequest.accountId;
                        mp.Stage__c   = 'Open';
                        mp.Month__c   = Constants.MONTH_VALUE_MAP.get(j);
                        mp.Financial_Year__c = String.valueOf(recordname=='Turkey'? String.valueOf(System.today().year()) : (recordname=='Dom/Int' ? fiscalYear : 'NA')); 

                        if(j == 9 || j == 10 || j == 11){
                            mp.Year__c    = String.valueOf(recordname=='Turkey'?String.valueOf(System.today().year()) : (recordname=='Dom/Int' ? String.valueOf(fiscalEndYearValue) : 'NA'));                         
                            mp.Name = Constants.MONTH_VALUE_MAP.get(j).toUpperCase()+'-'+ mp.Year__c +'-'+ mpcrRequest.mPlanList[j].Account__r.SAP_Code__c +'-Monthly Plan';
                            mp.MPUID__c   = mpcrRequest.mPlanList[j].Account__r.SAP_Code__c+Constants.MONTH_VALUE_MAP.get(j)+mp.Year__c;
                        }else{
                            mp.Year__c= String.valueOf(System.today().year());
                            mp.Name = Constants.MONTH_VALUE_MAP.get(j).toUpperCase()+'-'+ mp.Year__c +'-'+ mpcrRequest.mPlanList[j].Account__r.SAP_Code__c +'-Monthly Plan';
                            mp.MPUID__c   = mpcrRequest.mPlanList[j].Account__r.SAP_Code__c+(j+1)+Constants.MONTH_VALUE_MAP.get(j)+mp.Year__c;    
                        }
                        monthlyPlansList.add(mp);
                    }
                    

                }
                //System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->BATCH-->LIST2INSERT-->'+monthlyPlansList);
                //System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->BATCH-->LIST2INSERT SIZE-->'+monthlyPlansList.size());
                 Database.SaveResult[] srList = Database.insert(monthlyPlansList);
               // System.debug('ZZZ In AccountProcessHandler.cls-->createMonthlyPlanRecord_M-->BATCH-->DML Result-->'+srList);
             
            }
        }
     
    }
    global class MonthlyPlanCreationRequest {
        
        @InvocableVariable(required=true)
        global ID accountId;
        
        @InvocableVariable(required=true)
        global Integer numberOfMonthlyPlanRecords;
        
        global Boolean isFromBatch = false;
        
        global Monthly_Plan__c mPlan = new Monthly_Plan__c();
        
        global List<Monthly_Plan__c> mPlanList = new List<Monthly_Plan__c>();
        
        global String previousFiscalYear = '';
        
        global String SAPCode ='';
        
        // global Map<Id,List<Monthly_Plan__c>> accAndAllItsMP = new Map<Id,List<Monthly_Plan__c>>();
    }
    
    class AccountProcessHandlerException extends Exception{}
}