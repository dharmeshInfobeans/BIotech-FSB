global class QuarterlyCMERTMCalculation {
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    
    global QuarterlyCMERTMCalculation(){
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND /*StartDate = LAST_N_FISCAL_QUARTERS:2 AND*/ 
                                      StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
    }
    
    public AggregateResult[] QuarterlyCMERTMTarget(KRA_Configuration__c KRAConfig, string rolename, List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        
        string queryCMERTMTargetDivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                queryCMERTMTargetDivision += 'Sales_Employee__r.DivisionT__C like \''+divs+'%\'';
                if(cnt < Div.size()){
                    queryCMERTMTargetDivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryCMERTMTargetDivision***'+queryCMERTMTargetDivision);
        string targettype = 'CME-RTM';
        string queryCMERTMTargetSelect = 'SUM(Target__c)target ';
        string queryCMERTMTargetWhere;
        string queryCMERTMTargetGrpBy;        
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        
        if(rolename == 'RSM'){
            queryCMERTMTargetSelect += ',Sales_Employee__c,State__c ';
            queryCMERTMTargetWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Target_Type__c =: targettype ';
            queryCMERTMTargetGrpBy ='Sales_Employee__c,State__c ';
        } else{
            queryCMERTMTargetSelect += ',Sales_Employee__c,State__c ';
            queryCMERTMTargetWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryCMERTMTargetDivision +') AND Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Target_Type__c =: targettype ';
            queryCMERTMTargetGrpBy ='Sales_Employee__c,State__c ';
        }
        String queryCMERTMTarget = 'Select ' + queryCMERTMTargetSelect + ' from KRA_Target__c where '+queryCMERTMTargetWhere + ' Group By '+ queryCMERTMTargetGrpBy;
        system.debug('**queryCMERTMTarget***'+queryCMERTMTarget);
        AggregateResult[] CMERTMTargetAggreRes = database.query(queryCMERTMTarget);
        system.debug('***CMERTMTargetAggreRes***'+CMERTMTargetAggreRes);
        return CMERTMTargetAggreRes;
    }
    
    public AggregateResult[] QuarterlyCMERTMVisitReport(KRA_Configuration__c KRAConfig, string rolename, List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        
        string queryCMERTMVisitReportDivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                queryCMERTMVisitReportDivision += 'Sales_Employee__r.DivisionT__C like \''+divs+'%\'';
                if(cnt < Div.size()){
                    queryCMERTMVisitReportDivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryCMERTMVisitReportDivision***'+queryCMERTMVisitReportDivision);
        
        string queryCMERTMVisitReportSelect = 'Count(Id)cnt ';
        string queryCMERTMVisitReportWhere;
        string queryCMERTMVisitReportGrpBy;
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        system.debug('***rolename***'+rolename);
        
        if(rolename == 'RSM'){
            queryCMERTMVisitReportSelect += ',Sales_Employee__c owner,State__c ';
            queryCMERTMVisitReportWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Date__c >=: startDate '+
                'AND Date__c <=: endDate ';
            queryCMERTMVisitReportGrpBy ='Sales_Employee__c,State__c ';
        } else{
            queryCMERTMVisitReportSelect += ',Sales_Employee__c owner,State__c ';
            queryCMERTMVisitReportWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryCMERTMVisitReportDivision +') AND Date__c >=: startDate '+
                'AND Date__c <=: endDate ';
            queryCMERTMVisitReportGrpBy ='Sales_Employee__c,State__c ';
        }
        
        String queryCMERTMVisitReport = 'Select ' + queryCMERTMVisitReportSelect + ' from Visit_Report__c where '+queryCMERTMVisitReportWhere + ' Group By '+ queryCMERTMVisitReportGrpBy;
        system.debug('**queryCMERTMVisitReport***'+queryCMERTMVisitReport);
        AggregateResult[] CMERTMVisitReportAggreRes = database.query(queryCMERTMVisitReport);
        system.debug('***CMERTMVisitReportAggreRes***'+CMERTMVisitReportAggreRes);
        return CMERTMVisitReportAggreRes;
    }
    
    public void calculateCMERTM(KRA_Configuration__c KRAConfig, string rolename, List<string> Div) {
        
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        List<KRA_Parameter_Detail__c> KRAParam = KRAConfig.KRA_Details__r;
        KRA_Calculation__c kracalc = new KRA_Calculation__c();
        AggregateResult[] CMERTMTargetars = QuarterlyCMERTMTarget(KRAConfig,rolename,Div);
        AggregateResult[] CMERTMVisitReportars = QuarterlyCMERTMVisitReport(KRAConfig,rolename,Div);
        
        system.debug('***KRAConfig***'+KRAConfig);
        system.debug('***rolename***'+rolename);
        system.debug('***KRAParam***'+KRAParam);
        
        for(AggregateResult CMERTMTarget :CMERTMTargetars){
            
            kracalc = new KRA_Calculation__c();
            kracalc.KRA_Configuration__c = KRAConfig.Id;
            kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracalc.Region__c = (ID) CMERTMTarget.get('State__c');
            kracalc.OwnerId = (ID) CMERTMTarget.get('Sales_Employee__c');
            kracalc.Target__c = (Decimal) CMERTMTarget.get('target');
            for(AggregateResult CMERTMVisitReport : CMERTMVisitReportars){
                if(CMERTMTarget.get('Sales_Employee__c') == CMERTMVisitReport.get('owner') 
                   && CMERTMTarget.get('State__c') == CMERTMVisitReport.get('State__c')){
                       //   if((rolename == 'RSM') || (rolename!='RSM' && KRATarget.get('Division__c') == KRAActual.get('Division__c'))){
                       system.debug('***(Integer) CMERTMVisitReport.get(cnt) ***'+(Integer) CMERTMVisitReport.get('cnt') );
                       system.debug('***(Integer) CMERTMTarget.get(target)***'+(Decimal) CMERTMTarget.get('target'));
                       kracalc.Actual__c = (Integer) CMERTMVisitReport.get('cnt');
                       kracalc.Percentage__c = ((Integer) CMERTMVisitReport.get('cnt') / (Decimal) CMERTMTarget.get('target')) * 100;
                       for(KRA_Parameter_Detail__c kra :  KRAParam) {
                           if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                              || (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                                  kracalc.Points__c = kra.Points__c;
                                  break;
                              } 
                       }
                       //  }
                   }
            }
            lstKRACal.add(kracalc); 
        }
        insert lstKRACal;
    }
}