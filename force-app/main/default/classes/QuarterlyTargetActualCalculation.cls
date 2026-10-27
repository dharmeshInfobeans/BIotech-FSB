global class QuarterlyTargetActualCalculation {
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    
    global QuarterlyTargetActualCalculation(){
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND /*StartDate = LAST_N_FISCAL_QUARTERS:2 AND*/ 
                                      StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
    }
    
    public AggregateResult[] QuarterlyTargetCalculation(KRA_Configuration__c KRAConfig, string rolename){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        Id prod1 = KRAConfig.Product_1__c;
        system.debug('***prod1***'+prod1);
        Id prod2 = KRAConfig.Product_2__c;
        system.debug('***prod2***'+prod2);
        if(KRAConfig.Division__c!=null){
            String[] tmpString = KRAConfig.Division__c.split(';');
            
            system.debug('***tmpString***'+tmpString);
        }
        system.debug('***rolename***'+rolename);
        string queryTargetSelect = 'SUM(Target_Quantity__c)targetQty,SUM(Target_Amount__c)targetAmt ';
        string queryTargetWhere;
        string queryTargetGrpBy;        
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        if(rolename == 'RSM'){
            queryTargetSelect += ',Sales_User__c,Region__c ';
            queryTargetWhere = ' Sales_User__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Start_Date__c >=: startDate '+
                'AND Start_Date__c <=: endDate ';
            queryTargetGrpBy ='Sales_User__c,Region__c ';
        }else{ 
            queryTargetSelect += ',Sales_User__c,Region__c,Product__r.Division__c ';
            queryTargetWhere = ' Sales_User__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Start_Date__c >=: startDate '+
                'AND Start_Date__c <=: endDate'+' AND Product__r.Division__c IN: tmpString';
            queryTargetGrpBy ='Sales_User__c,Region__c,Product__r.Division__c ';
        }
        
        if(KRAConfig.Parameter__c == 'Product-Single'){
            queryTargetSelect = queryTargetSelect + ',Product__c';
            queryTargetWhere = queryTargetWhere + ' AND Product__c =: prod1';
            queryTargetGrpBy = queryTargetGrpBy + ',Product__c';
        }else if(KRAConfig.Parameter__c == 'Product-Combination'){
            queryTargetSelect = queryTargetSelect;
            queryTargetWhere = queryTargetWhere + ' AND (Product__c =: prod1 OR Product__c =: prod2)';                     
            queryTargetGrpBy = queryTargetGrpBy;
        }
        String queryTarget = 'Select ' + queryTargetSelect + ' from Monthly_AOP__c where '+queryTargetWhere + ' Group By '+ queryTargetGrpBy;
        system.debug('**queryTarget***'+queryTarget);
        AggregateResult[] TargetAggreRes = database.query(queryTarget);
        system.debug('***TargetAggreRes***'+TargetAggreRes);
        return TargetAggreRes;
    }
    
    public AggregateResult[] QuarterlyActualCalculation(KRA_Configuration__c KRAConfig, string rolename){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        Id prod1 = KRAConfig.Product_1__c;
        system.debug('***prod1***'+prod1);
        Id prod2 = KRAConfig.Product_2__c;
        system.debug('***prod2***'+prod2);
        if(KRAConfig.Division__c != null){
            String[] tmpString = KRAConfig.Division__c.split(';');
            system.debug('***tmpString***'+tmpString);
        }
        string customerRegion = 'Domestic';
        string queryActualSelect = 'SUM(Quantity__c)Qty, SUM(Net_Value_Item__c)Amt ';
        string queryActualWhere;
        string queryActualGrpBy;
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        system.debug('***rolename***'+rolename);
        if(rolename == 'RSM'){
            queryActualSelect += ',RSM__c owner,Account__r.region__c ';
            queryActualWhere = ' RSM__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND RSM__c != null AND Region_of_Customer__c =: customerRegion ';
            queryActualGrpBy ='RSM__c,Account__r.region__c ';
        }else if(rolename == 'DM'){
            queryActualSelect += ',Div_Manager__c owner,Account__r.region__c,Product__r.Division__c ';
            queryActualWhere = ' Div_Manager__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND Div_Manager__c != null AND Region_of_Customer__c =: customerRegion ' +' AND Product__r.Division__c IN: tmpString';
            queryActualGrpBy ='Div_Manager__c,Account__r.region__c,Product__r.Division__c ';
        }else if(rolename == 'SSE'){
            queryActualSelect += ',Sales_Employee__c owner,Account__r.region__c,Product__r.Division__c ';
            queryActualWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND Sales_Employee__c != null AND Region_of_Customer__c =: customerRegion '+' AND Product__r.Division__c IN: tmpString';
            queryActualGrpBy ='Sales_Employee__c,Account__r.region__c,Product__r.Division__c ' ;
        }else if(rolename == 'ASM'){
            queryActualSelect += ',ASMs__c owner,Account__r.region__c,Product__r.Division__c ';
            queryActualWhere = ' ASMs__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND ASMs__c != null AND Region_of_Customer__c =: customerRegion '+' AND Product__r.Division__c IN: tmpString';
            queryActualGrpBy ='ASMs__c,Account__r.region__c,Product__r.Division__c ';
        }else if(rolename == 'ZDM'){
            queryActualSelect += ',ZBMs__c owner,Account__r.region__c,Product__r.Division__c ';
            queryActualWhere = ' ZBMs__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND ZBMs__c != null AND Region_of_Customer__c =: customerRegion '+' AND Product__r.Division__c IN: tmpString';
            queryActualGrpBy ='ZBMs__c,Account__r.region__c,Product__r.Division__c ';
        }else if(rolename == 'BDM'){
            queryActualSelect += ',Sales_Employee__c owner,Account__r.region__c,Product__r.Division__c ';
            queryActualWhere = ' ZBMs__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND Sales_Employee__c != null AND Region_of_Customer__c =: customerRegion '+' AND Product__r.Division__c IN: tmpString';
            queryActualGrpBy ='Sales_Employee__c,Account__r.region__c,Product__r.Division__c ';
        }
        
        if(KRAConfig.Parameter__c == 'Product-Single'){
            queryActualSelect = queryActualSelect + ',Product__c ';
            queryActualWhere = queryActualWhere + ' AND Product__c =: prod1 ';
            queryActualGrpBy = queryActualGrpBy + ',Product__c ';
        }else if(KRAConfig.Parameter__c == 'Product-Combination'){
            queryActualSelect = queryActualSelect;
            queryActualWhere = queryActualWhere + ' AND (Product__c =: prod1 OR Product__c =: prod2) ';                     
            queryActualGrpBy = queryActualGrpBy;
        }
        
        String queryActual = 'Select ' + queryActualSelect + ' from Z_Incentive__c where '+queryActualWhere + ' Group By '+ queryActualGrpBy;
        system.debug('**queryActual***'+queryActual);
        AggregateResult[] ActualAggreRes = database.query(queryActual);
        system.debug('***ActualAggreRes***'+ActualAggreRes);
        return ActualAggreRes;
    }
    
    public void calculateKRA(KRA_Configuration__c KRAConfig, string rolename) {
        
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        AggregateResult[] Targetars = QuarterlyTargetCalculation(KRAConfig,rolename);
        AggregateResult[] Actualars = QuarterlyActualCalculation(KRAConfig,rolename);
        
        Map<String,Id> mpDiv = new Map<String,Id>();
        if(KRAConfig.Division__c != null)
        {
            if(KRAConfig.Division__c.contains(';'))
            {
                for(String s :KRAConfig.Division__c.split(';'))
                {
                    mpDiv.put(s,KRAConfig.Id);
                }
            }
            else
            {
                mpDiv.put(KRAConfig.Division__c,KRAConfig.Id);
            }
        }
        system.debug('***KRAConfig***'+KRAConfig);
        system.debug('***rolename***'+rolename);
        List<KRA_Parameter_Detail__c> KRAParam = KRAConfig.KRA_Details__r;
        system.debug('***KRAParam***'+KRAParam);
        
        KRA_Calculation__c kracalc = new KRA_Calculation__c();
        
        for(AggregateResult KRATarget :Targetars){
            
            kracalc = new KRA_Calculation__c();
            kracalc.Target__c = (decimal) KRATarget.get('targetAmt');
            kracalc.KRA_Configuration__c = KRAConfig.Id;
            kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracalc.Region__c = (ID) KRATarget.get('Region__c');
            system.debug('***kracalc.Target__c***'+kracalc.Target__c);
            kracalc.OwnerId = (ID) KRATarget.get('Sales_User__c');
            
            for(AggregateResult KRAActual : Actualars){
                if(KRATarget.get('Sales_User__c') == KRAActual.get('owner') 
                   && KRATarget.get('Region__c') == KRAActual.get('region__c')){
                       if((rolename == 'RSM') || (rolename!='RSM' && KRATarget.get('Division__c') == KRAActual.get('Division__c'))){
                           kracalc.Actual__c = (decimal) KRAActual.get('Amt');
                           kracalc.Percentage__c = (kracalc.Actual__c / kracalc.Target__c) * 100;
                           for(KRA_Parameter_Detail__c kra :  KRAParam) {
                               if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                                  || (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                                      kracalc.Points__c = kra.Points__c;
                                      break;
                                  } 
                           }
                       }
                   }
            }
            lstKRACal.add(kracalc); 
        }
        insert lstKRACal;
    }
}