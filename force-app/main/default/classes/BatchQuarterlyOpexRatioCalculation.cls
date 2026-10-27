global class BatchQuarterlyOpexRatioCalculation implements Database.Batchable<sObject>{
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                         Financial_Year__r.End_Date__c,Product_1__c,Product_2__c,Division__c,DivisionT__c, 
                                         (select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                          from KRA_Details__r) from KRA_Configuration__c where Parameter__c = 'Opex to Sales Ratio']);
    }
    
    global void execute(Database.BatchableContext BC, List<KRA_Configuration__c> scope){
        List<string> rolename = new list<string>(); 
        Set<string> division = new set<string>(); 
        Set<string> rolewise = new set<string>(); 
        if(scope!=null){
            for(KRA_Configuration__c kras : scope){
                system.debug('***kras.Role__c***'+kras.Role__c);
                if(kras.Role__c.contains(';')){
                    rolename.addAll(kras.Role__c.split(';'));
                    rolewise.addAll(kras.Role__c.split(';'));
                } else {
                    rolename.add(kras.Role__c);
                    rolewise.add(kras.Role__c);
                }
                if(kras.DivisionT__c != null){
                    if(kras.DivisionT__c.contains(',')){
                        division.addAll(kras.DivisionT__c.split(','));
                    } else {
                        division.add(kras.DivisionT__c);
                    }
                }
            }
        }
        
        string queryRole ='';
        string roles;
        if(rolewise.size() > 0){
            integer cnt =1;
            system.debug('***rolewise.size()***'+rolewise.size());
            for(string role : rolewise){
                queryRole += 'Sales_Employee__r.UserRole.Name like \''+role+'%\'';
                roles = role;
                if(cnt < roleWise.size()){
                    queryRole +=' OR ';
                } 
                system.debug('***role***'+role);
                system.debug('***roles***'+roles);
                cnt++;
            }
        }
        
        string queryDivision ='';
        if(division.size() > 0){
            integer cnt =1;
            system.debug('***division.size()***'+division.size());
            for(string div : division){
                queryDivision += 'Sales_Employee__r.DivisionT__C like \''+div+'%\'';
                if(cnt < division.size()){
                    queryDivision +=' OR ';
                } 
                system.debug('***division***'+division);
                cnt++;
            }
        }
        system.debug('***queryDivision***'+queryDivision);
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period 
                                      where type = 'QUARTER' /*AND StartDate = LAST_N_FISCAL_QUARTERS:2*/ AND StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
        
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        system.debug('***rolewise***'+rolewise);
        string querySelect = 'SUM(Total_Expense__c) TotalExpenses,SUM(Total_Salary__c) TotalSalary,SUM(Net_Sales_Value__c) NetSale' + 
            ',SUM(Total_OPEX__c) totalopex,Sales_Employee__c salesUser,Region__c';
        string queryGroupBy = 'Sales_Employee__c,Region__c';
        string querywhere = 'Expense_From_Date__c >=: startDate AND Expense_To_Date__c <=: endDate';
        string ActualQuery;
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        Boolean found = false;
        AggregateResult[] OPEXAggrResLst;
        for(string rr : rolewise){
            found = false;
            system.debug('***rr***'+rr);
            if(rr == 'RSM'){ 
                ActualQuery = 'Select '+ querySelect + ' From OPEX__c where ' + 'Sales_Employee__r.UserRole.Name like \''+rr+'%\'' + ' AND ' + querywhere + ' Group By '+ queryGroupBy;
                system.debug('***ActualQuery***'+ActualQuery);
            }
            else if(rr == 'ZDM'){
                ActualQuery = 'Select '+ querySelect + ' From OPEX__c where ' + 'Sales_Employee__r.UserRole.Name like \''+rr+'%\'' + ' AND ' + querywhere + ' AND ('+ queryDivision + ') Group By '+ queryGroupBy;
                system.debug('***ActualQuery***'+ActualQuery);
            }else if(rr == 'DM'){
                found = true;
                ActualQuery = 'Select '+ querySelect + ' From OPEX__c where ' + 'Sales_Employee__r.UserRole.Name like \''+rr+'%\'' + ' AND ' + querywhere + ' AND ('+ queryDivision + ') Group By '+ queryGroupBy;
                system.debug('***ActualQuery***'+ActualQuery);
            }else if(rr == 'ASM'){
                ActualQuery = 'Select '+ querySelect + ' From OPEX__c where ' + 'Sales_Employee__r.UserRole.Name like \''+rr+'%\'' + ' AND ' + querywhere + ' AND ('+ queryDivision + ') Group By '+ queryGroupBy;
                system.debug('***ActualQuery***'+ActualQuery);
            }else if(rr == 'BDM'){
                ActualQuery = 'Select '+ querySelect + ' From OPEX__c where ' + 'Sales_Employee__r.UserRole.Name like \''+rr+'%\'' + ' AND ' + querywhere + ' AND ('+ queryDivision + ') Group By '+ queryGroupBy;
                system.debug('***ActualQuery***'+ActualQuery);
            }else if(rr == 'SSE'){
                ActualQuery = 'Select '+ querySelect +' From OPEX__c where ' + 'Sales_Employee__r.UserRole.Name like \''+rr+'%\'' + ' AND ' + querywhere + ' AND ('+ queryDivision + ') Group By '+ queryGroupBy;
                system.debug('***ActualQuery***'+ActualQuery);
            }
            
            OPEXAggrResLst = database.query(ActualQuery);
            system.debug('***OPEXAggrResLst***'+OPEXAggrResLst);
            for(KRA_Configuration__c kraconfig : scope){
                for(AggregateResult OPEXAggrRes : OPEXAggrResLst){
                    system.debug('***OPEXAggrRes***'+OPEXAggrRes);
                    system.debug('***rr***'+rr);
                    if(kraconfig.Role__c.contains(rr))
                    {
                        KRA_Calculation__c kracalc = new KRA_Calculation__c();
                        kracalc.KRA_Configuration__c = kraconfig.Id;
                        kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
                        kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
                        kracalc.OwnerId = (ID) OPEXAggrRes.get('salesUser');
                        kracalc.Region__c = (ID) OPEXAggrRes.get('Region__c');
                        kracalc.Target__c = (decimal) OPEXAggrRes.get('totalopex');
                        kracalc.Actual__c = (decimal) OPEXAggrRes.get('NetSale');
                        system.debug('***totalopex***'+(decimal) OPEXAggrRes.get('totalopex'));
                        system.debug('***NetSale***'+(decimal) OPEXAggrRes.get('NetSale'));
                        if((decimal) OPEXAggrRes.get('NetSale') != 0 && (decimal) OPEXAggrRes.get('totalopex') != 0){
                            kracalc.Percentage__c = ((decimal) OPEXAggrRes.get('totalopex') / (decimal) OPEXAggrRes.get('NetSale')) * 100;
                        }else{
                            kracalc.Percentage__c = 0;
                        }
                        for(KRA_Parameter_Detail__c kra :  kraconfig.KRA_Details__r) {
                            if((kracalc.Percentage__c > 12 && kra.Achievement_from__c == 12) 
                               || (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                                   kracalc.Points__c = kra.Points__c;
                                   break;
                               } 
                        }
                        lstKRACal.add(kracalc); 
                    }
                }
            }
        }
        if(lstKRACal != null)
            insert lstKRACal;
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('In Opex to Sales Ratio batch finish method : ');
    }
}