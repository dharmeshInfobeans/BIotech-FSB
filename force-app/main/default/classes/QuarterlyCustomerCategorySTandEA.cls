global class QuarterlyCustomerCategorySTandEA {
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    
    global QuarterlyCustomerCategorySTandEA(){
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' /*AND StartDate = LAST_N_FISCAL_QUARTERS:2*/ AND 
                                      StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
    }
    
    public AggregateResult[] QuarterlyCustomerCategorySTandEACalculation(KRA_Configuration__c KRAConfig, string rolename,List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        string queryCustomerCategorySTandEADivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                if(rolename == 'DM'){
                    queryCustomerCategorySTandEADivision += 'DM__r.DivisionT__c like \''+divs+'%\'';
                } else if(rolename == 'ASM'){
                    queryCustomerCategorySTandEADivision += 'ASM__r.DivisionT__c like \''+divs+'%\'';
                }
                if(cnt < Div.size()){
                    queryCustomerCategorySTandEADivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryCustomerCategorySTandEADivision***'+queryCustomerCategorySTandEADivision);
        string queryCustomerCategorySTandEASelect;
        string queryCustomerCategorySTandEAWhere;
        string queryCustomerCategorySTandEAGrpBy;        
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        if(rolename == 'RSM'){
            queryCustomerCategorySTandEASelect = 'COUNT(id)cnt,RSM__c owner ';
            queryCustomerCategorySTandEAWhere = ' RSM__r.UserRole.Name LIKE \''+rolename+'%\' AND ' + ' Outstanding_As_On_Date__c >=: startDate '+ 'AND Outstanding_As_On_Date__c <=: endDate ';
            queryCustomerCategorySTandEAGrpBy ='RSM__c ';   
        }else if(rolename == 'DM'){
            queryCustomerCategorySTandEASelect = 'COUNT(id)cnt,DM__c owner ';
            queryCustomerCategorySTandEAWhere = ' DM__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryCustomerCategorySTandEADivision + ') AND Outstanding_As_On_Date__c >=: startDate '+ 'AND Outstanding_As_On_Date__c <=: endDate ';
            queryCustomerCategorySTandEAGrpBy ='DM__c ';   
        }else if(rolename == 'ASM'){
            queryCustomerCategorySTandEASelect = 'COUNT(id)cnt,ASM__c owner ';
            queryCustomerCategorySTandEAWhere = ' ASM__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryCustomerCategorySTandEADivision + ') AND Outstanding_As_On_Date__c >=: startDate '+ 'AND Outstanding_As_On_Date__c <=: endDate ';
            queryCustomerCategorySTandEAGrpBy ='ASM__c ';   
        }
        String queryCustomerCategorySTandEA = 'Select ' + queryCustomerCategorySTandEASelect + ' from DSO__c where '+queryCustomerCategorySTandEAWhere + 'Group By '+queryCustomerCategorySTandEAGrpBy;
        system.debug('**queryCustomerCategorySTandEA***'+queryCustomerCategorySTandEA);
        AggregateResult[] CustomerCategorySTandEAAggreRes = database.query(queryCustomerCategorySTandEA);
        system.debug('***CustomerCategorySTandEAAggreRes***'+CustomerCategorySTandEAAggreRes);
        return CustomerCategorySTandEAAggreRes;
    }
    
    public AggregateResult[] QuarterlyActualCustomerCategorySTandEACalculation(KRA_Configuration__c KRAConfig, string rolename,List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        string Quad1 = 'ST';
        string Quad2 = 'EA';
        string queryActualCustomerCategorySTandEADivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                if(rolename=='DM'){
                    queryActualCustomerCategorySTandEADivision += 'DM__r.DivisionT__C like \''+divs+'%\'';
                }else if(rolename=='ASM'){
                    queryActualCustomerCategorySTandEADivision += 'ASM__r.DivisionT__C like \''+divs+'%\'';
                }
                if(cnt < Div.size()){
                    queryActualCustomerCategorySTandEADivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryActualCustomerCategorySTandEADivision***'+queryActualCustomerCategorySTandEADivision);
        string queryActualCustomerCategorySTandEASelect = 'COUNT(Id)cnt ';
        string queryActualCustomerCategorySTandEAWhere;
        string queryActualCustomerCategorySTandEAGrpBy;
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        system.debug('***rolename***'+rolename);
        if(rolename == 'RSM'){
            queryActualCustomerCategorySTandEASelect += ',RSM__c owner ';
            queryActualCustomerCategorySTandEAWhere = ' RSM__r.UserRole.Name LIKE \''+rolename+'%\' AND ' + ' Outstanding_As_On_Date__c >=: startDate '+
                'AND Outstanding_As_On_Date__c <=: endDate AND (Quadrant__c =: Quad1 OR Quadrant__c =: Quad2) '; 
            queryActualCustomerCategorySTandEAGrpBy ='RSM__c ';
        }else if(rolename == 'DM'){
            queryActualCustomerCategorySTandEASelect += ',DM__c owner ';
            queryActualCustomerCategorySTandEAWhere = ' DM__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryActualCustomerCategorySTandEADivision + ') AND Outstanding_As_On_Date__c >=: startDate '+
                'AND Outstanding_As_On_Date__c <=: endDate AND (Quadrant__c =: Quad1 OR Quadrant__c =: Quad2) '; 
            queryActualCustomerCategorySTandEAGrpBy ='DM__c ';
        }else if(rolename == 'ASM'){
            queryActualCustomerCategorySTandEASelect += ',ASM__c owner ';
            queryActualCustomerCategorySTandEAWhere = ' ASM__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryActualCustomerCategorySTandEADivision + ') AND Outstanding_As_On_Date__c >=: startDate '+
                'AND Outstanding_As_On_Date__c <=: endDate AND (Quadrant__c =: Quad1 OR Quadrant__c =: Quad2) '; 
            queryActualCustomerCategorySTandEAGrpBy ='ASM__c ';
        }
        String queryActualCustomerCategorySTandEA = 'Select ' + queryActualCustomerCategorySTandEASelect + ' from DSO__c where '+queryActualCustomerCategorySTandEAWhere + ' Group By '+ queryActualCustomerCategorySTandEAGrpBy;
        system.debug('**queryActualCustomerCategorySTandEA***'+queryActualCustomerCategorySTandEA);
        AggregateResult[] ActualCustomerCategorySTandEAAggreRes = database.query(queryActualCustomerCategorySTandEA);
        system.debug('***ActualCustomerCategorySTandEAAggreRes***'+ActualCustomerCategorySTandEAAggreRes);
        return ActualCustomerCategorySTandEAAggreRes;
    }
    
    public void calculateKRACustomerCategorySTandEA(KRA_Configuration__c KRAConfig, string rolename,List<string> Div) {
        
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        AggregateResult[] Targetars = QuarterlyCustomerCategorySTandEACalculation(KRAConfig,rolename,Div);
        AggregateResult[] Actualars = QuarterlyActualCustomerCategorySTandEACalculation(KRAConfig,rolename,Div);
        
        system.debug('***KRAConfig***'+KRAConfig);
        system.debug('***rolename***'+rolename);
        List<KRA_Parameter_Detail__c> KRAParam = KRAConfig.KRA_Details__r;
        system.debug('***KRAParam***'+KRAParam);
        KRA_Calculation__c kracalc = new KRA_Calculation__c();
        
        for(AggregateResult KRATarget :Targetars){
            
            kracalc = new KRA_Calculation__c();
            kracalc.Target__c = (Integer) KRATarget.get('cnt');
            kracalc.KRA_Configuration__c = KRAConfig.Id;
            kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracalc.OwnerId = (ID) KRATarget.get('owner');
            
            for(AggregateResult KRAActual : Actualars){
                if(KRATarget.get('owner') == KRAActual.get('owner')){
                    kracalc.Actual__c = (Integer) KRAActual.get('cnt');
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
            lstKRACal.add(kracalc); 
        }
        insert lstKRACal;
    }
}