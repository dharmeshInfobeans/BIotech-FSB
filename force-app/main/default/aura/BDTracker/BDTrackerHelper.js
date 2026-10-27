({
   getURLParameterValue: function() {
 
        var querystring = location.search.substr(1);
        var paramValue = {};
        querystring.split("&").forEach(function(part) {
            var param = part.split("=");
            paramValue[param[0]] = decodeURIComponent(param[1]);
        });
 
        console.log('paramValue-' + paramValue);
        return paramValue;
    },
    getWeeksOfYearValue : function(component,event,helper,uid,gotoWeek){
       //var selYr= component.get("v.selectedMonth");
      
        var action = component.get("c.getWeekssOfyear");
        action.setParams({'year':component.get('v.selectedYear'),'uidValue':uid});
        action.setCallback(this,function(response){
            debugger;
             if(response.getState()==='SUCCESS'){
                
               var result = response.getReturnValue();
                if(!$A.util.isUndefinedOrNull(uid)){
                 
                 component.set('v.selectedMonth',gotoWeek);     
                }else{ 
                    var weekValue = component.get('v.currentWeek');
                    for(var rang = 0;rang < result.length;rang++){
                        
                        if(parseInt(weekValue) >= parseInt(result[rang].split(' ')[0].split('-')[0]) &&
                           parseInt(weekValue) <= parseInt(result[rang].split(' ')[0].split('-')[1]) ){
                            
                            component.set('v.selectedMonth',result[rang]); 
                            
                        } 
                    }
                }
                //component.set('v.selectedMonth',result[0].toString());
                component.set('v.lstMonths',result);
                
                this.defaultWeeks(component,event,helper,null);
                this.getRecords(component,event,helper);
                this.getLockSubmit(component, event, helper); 
                this.updateRequestToSubmit(component,event,helper);
                this.RSMApprovalforSubmit(component,event,helper);
            }
        });
        $A.enqueueAction(action);
    },
    defaultWeeks:function(component,event,helper,nxtYearValue){
        
        debugger;
        var indVal = event.getParam("indexValue");
        var BDWrapper = component.get('v.lstBDTrackerWrapper');
        var mont = component.get('v.selectedMonth');
        var  month = mont.split(' ');
        var lstcurMonth = component.get('v.lstMonths');
        var lstnxtMonth = component.get('v.nextYearWeeks');
        var selYear = component.get('v.selectedYear');
        var curIndex;
        var nxtrng;
        var curRng = month[0].split('-')[0];
        var rng;
        //debugger;
        for(var k=0;k<lstcurMonth.length;k++){
            
            if(lstcurMonth[k] == mont){
                
                //Start :
                if(($A.util.isUndefinedOrNull(lstcurMonth[k+1]))){
                    
                    rng = lstnxtMonth[2].split(' ')[0].split('-')[1]; 
                    
                    var lst =[];
                    if((!$A.util.isUndefinedOrNull(nxtYearValue))){
                        if(parseInt(nxtYearValue) == new Date().getFullYear()){
                            for(var l =parseInt(lstcurMonth[k].split(' ')[0].split('-')[0]);l<= parseInt(lstcurMonth[k].split(' ')[0].split('-')[1]);l++){
                                
                                lst.push(l);
                            }
                        }
                    }else{
                        
                        for(var l =parseInt(lstcurMonth[k].split(' ')[0].split('-')[0]);l<= parseInt(lstcurMonth[k].split(' ')[0].split('-')[1]);l++){
                                
                                lst.push(l);
                            }
                    }
                    if(parseInt(nxtYearValue) > new Date().getFullYear() && (!$A.util.isUndefinedOrNull(nxtYearValue))){
                        for(var l =1;l<=parseInt(rng);l++){
                            lst.push(l); 
                        }
                    }
                    
                    component.set('v.lstEvalWeeks',lst);
                    component.set('v.lstCommWeeks',lst);
                    var lstYears = [];
                    lstYears.push(selYear);
                    lstYears.push((parseInt(selYear)+1).toString());
                    component.set('v.lstEvalYear',lstYears);
                    component.set('v.lstCommYear',lstYears);
                    component.set('v.isFutureWeek',false);
                    
                }else if(($A.util.isUndefinedOrNull(lstcurMonth[k+2]))){
                    
                    rng = lstnxtMonth[1].split(' ')[0].split('-')[1]; 
                    
                    var lst =[];
                    if((!$A.util.isUndefinedOrNull(nxtYearValue))){
                        if(parseInt(nxtYearValue) == new Date().getFullYear()){
                            for(var l =parseInt(lstcurMonth[k].split(' ')[0].split('-')[0]);l<= parseInt(lstcurMonth[k+1].split(' ')[0].split('-')[1]);l++){
                                
                                lst.push(l);
                            }
                        }
                    }else{
                        
                        for(var l =parseInt(lstcurMonth[k].split(' ')[0].split('-')[0]);l<= parseInt(lstcurMonth[k+1].split(' ')[0].split('-')[1]);l++){
                                
                                lst.push(l);
                            }
                    }
                    if(parseInt(nxtYearValue) > new Date().getFullYear() && (!$A.util.isUndefinedOrNull(nxtYearValue))){
                        for(var l = 1;l<=parseInt(rng);l++){
                            lst.push(l); 
                        }
                    }
                    
                    component.set('v.lstEvalWeeks',lst);
                    component.set('v.lstCommWeeks',lst);
                    var lstYears = [];
                    lstYears.push(selYear);
                    lstYears.push((parseInt(selYear)+1).toString());
                    component.set('v.lstEvalYear',lstYears);
                    component.set('v.lstCommYear',lstYears);
                    component.set('v.isFutureWeek',false);
                    
                }else if(($A.util.isUndefinedOrNull(lstcurMonth[k+3]))){
                    
                    rng = lstnxtMonth[0].split(' ')[0].split('-')[1]; 
                    
                    var lst =[];
                    if((!$A.util.isUndefinedOrNull(nxtYearValue))){
                        if(parseInt(nxtYearValue) == new Date().getFullYear()){
                            for(var l =parseInt(lstcurMonth[k].split(' ')[0].split('-')[0]);l<= parseInt(lstcurMonth[k+2].split(' ')[0].split('-')[1]);l++){
                                
                                lst.push(l);
                            }
                        }
                    }else{
                        
                        for(var l =parseInt(lstcurMonth[k].split(' ')[0].split('-')[0]);l<= parseInt(lstcurMonth[k+2].split(' ')[0].split('-')[1]);l++){
                                
                                lst.push(l);
                            }
                    }
                    if(parseInt(nxtYearValue) > new Date().getFullYear() && (!$A.util.isUndefinedOrNull(nxtYearValue))){
                        for(var l =1;l<=parseInt(rng);l++){
                            lst.push(l); 
                        }
                    }
                    
                    component.set('v.lstEvalWeeks',lst);
                    component.set('v.lstCommWeeks',lst);
                    
                    var lstYears = [];
                    lstYears.push(selYear);
                    lstYears.push((parseInt(selYear)+1).toString());
                    component.set('v.lstEvalYear',lstYears);
                    component.set('v.lstCommYear',lstYears);
                    component.set('v.isFutureWeek',false);
                    
                }else{
                    if(!($A.util.isUndefinedOrNull(lstcurMonth[k+3]))){
                        rng = lstcurMonth[k+3].split(' ')[0].split('-')[1]; 
                        
                        var lst =[];
                        for(var l =parseInt(curRng);l<=parseInt(rng);l++){
                            lst.push(l); 
                        }
                        
                        component.set('v.lstEvalWeeks',lst);
                        component.set('v.lstCommWeeks',lst);
                        component.set('v.isFutureWeek',true);
                    }
                }
                //End:  
                
            }
        }
        
       
        //END :
    },
    handleComponentEventHelper : function(component,event,helper){
       var selectedAccountGetFromEvent = event.getParam("recordByEvent");
        var BDWrapper = component.get('v.lstBDTrackerWrapper');
        var iNameVal = event.getParam("iName");
        var indVal = event.getParam("indexValue");
        var contact = event.getParam("contactId");
        var leng = BDWrapper.length;
        var validEntery = true;
       
  		//Start
   
        if(leng > 0){
            
            for(var i=0;i<BDWrapper.length;i++){
                for(var k=i+1;k<BDWrapper.length;k++){
                    
                    if(BDWrapper[i].objAccount!=null && BDWrapper[i].objcontact!=null && BDWrapper[i].objProduct!=null
                      && BDWrapper[k].objAccount!=null && BDWrapper[k].objcontact!=null && BDWrapper[k].objProduct!=null){
                        
                        if(BDWrapper[i].objAccount.Id ==BDWrapper[k].objAccount.Id && BDWrapper[i].objProduct.Id == BDWrapper[k].objProduct.Id &&
                           BDWrapper[i].objcontact.Id == BDWrapper[k].objcontact.Id){
                            
                            
                            validEntery =false;
                            
                            var cmpValue = component.find('customLookupproduct');
                                if(cmpValue.length > 0){
                                    var len = cmpValue.length;
                               		component.find('customLookupproduct')[len-1].callChild();     
                                }else{
                                   cmpValue.callChild();      
                                }
                               
                                for(var i=0;i<BDWrapper.length;i++){
                                    if(i == indVal){
                                        BDWrapper[indVal].objProduct = null;
                                        component.set("v.lstBDTrackerWrapper",BDWrapper);
                                    }
                                }
                            
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message":  $A.get("$Label.c.Account_and_product_with_contact_has_been_planned_already")
                            });
                            showToast.fire();
                        }
                    }
                }
            }
        }
        
   //End   
   
        
      if(validEntery){
         // debugger;
       if(iNameVal == 'standard:account'){
          
           if(selectedAccountGetFromEvent!= null ){
               
               component.set("v.selectedAccountId",selectedAccountGetFromEvent.Id);
               component.set("v.selectedAccountIdcheck",selectedAccountGetFromEvent.Id);
               var prodId = component.get("v.selectedProductIdcheck");
               var contId = component.get("v.selectedContactIdcheck");
               var accntId =component.get("v.selectedAccountIdcheck");
               
               if((!($A.util.isUndefinedOrNull(prodId))) && (!($A.util.isUndefinedOrNull(contId))) && (!($A.util.isUndefinedOrNull(accntId)))){
                   var action = component.get('c.validateAccount');
                   action.setParams({'accId':accntId,
                                     'conId':contId,
                                     'prodId':prodId});
                   action.setCallback(this,function(response){
                       if(response.getState()==='SUCCESS'){
                           var result = response.getReturnValue();
                           if(result){
                             
                               for(var i=0;i<BDWrapper.length;i++){
                                   
                                   if(result != null){
                                       
                                       if(i == indVal){
                                           
                                           BDWrapper[indVal].objAccount = result;
                                           component.set("v.selectedAccountId",BDWrapper[indVal].objAccount.Id);
                                           component.set("v.lstBDTrackerWrapper",BDWrapper);
                                       }
                                   }
                               }
                           }else{
                              var showToast = $A.get("e.force:showToast");
                                showToast.setParams({
                                    "type": "error",
                                    "message": $A.get("$Label.c.Account_and_product_with_contact_has_been_planned_already")
                                });
                                showToast.fire();
                           }
                       } 
                   });
                   $A.enqueueAction(action);
               }else{
                   
               var action = component.get("c.getAccountInfo");
               action.setParams({
                   'accountId': selectedAccountGetFromEvent.Id
               });
               action.setCallback(this,function(response){
                   
                   if(response.getState()==='SUCCESS'){
                       //  alert(indVal);
                       var result = response.getReturnValue();
                       for(var i=0;i<BDWrapper.length;i++){
                           
                           if(result != null){
                               
                               if(i == indVal){
                                   BDWrapper[indVal].objAccount = result;
                                   component.set("v.selectedAccountId",BDWrapper[indVal].objAccount.Id);
                                   component.set("v.lstBDTrackerWrapper",BDWrapper);
                               }
                               
                           }else{
                               component.set("v.lstBDTrackerWrapper[i].objAccount",null);
                           }
                       }
                   }
               });
               $A.enqueueAction(action);
           }
       }
       } else if(iNameVal == 'standard:contact'){
           var valid =true;
           if(BDWrapper[indVal].objProduct !=null){
               //START :CHECK DUPLICACY ON CONTACT SELECTION.
               var action1 = component.get("c.getProductInfo");
               
               action1.setParams({
                   'productId': BDWrapper[indVal].objProduct.Id,
                   'accountId' : BDWrapper[indVal].objAccount.Id,
                   'contactId':selectedAccountGetFromEvent.Id
               });
               action1.setCallback(this,function(response){
                   
                   if(response.getState()==='SUCCESS'){
                       
                       var result = response.getReturnValue();
                       if(result != null){
                           
                           var accId = BDWrapper[indVal].objAccount.Id;
                           if(accId != 'blank' || accId!=null){
                               if(selectedAccountGetFromEvent!= null ){
                                   component.set("v.selectedContactId",selectedAccountGetFromEvent.Id);
                                   var action = component.get("c.getContactInfo");
                                   action.setParams({
                                       'contactId': selectedAccountGetFromEvent.Id,
                                       'accountId' : accId 
                                   });
                                   action.setCallback(this,function(response){
                                       
                                       if(response.getState()==='SUCCESS'){
                                           
                                           var result = response.getReturnValue();
                                           for(var i=0;i<BDWrapper.length;i++){
                                               
                                               if(result != null){
                                                   if(i == indVal){
                                                       BDWrapper[indVal].objcontact = result;
                                                       BDWrapper[indVal].ConId = result.Id;
                                                       BDWrapper[indVal].AccId = accId;
                                                       component.set("v.lstBDTrackerWrapper",BDWrapper);
                                                   }
                                                   
                                               }
                                           }
                                       }
                                   });
                                   $A.enqueueAction(action);
                               }
                           }
                       }else{
                           
                           var cmpValue = component.find('customLookupcontact');
                                if(cmpValue.length > 0){
                                    var len = cmpValue.length;
                               		component.find('customLookupcontact')[len-1].callChild(); 
                                   
                                }else{
                                   cmpValue.callChild();      
                                }
                               
                                for(var i=0;i<BDWrapper.length;i++){
                                    if(i == indVal){
                                        BDWrapper[indVal].objcontact = null;
                                        component.set("v.lstBDTrackerWrapper",BDWrapper);
                                    }
                                }
                                var showToast = $A.get("e.force:showToast");
                                showToast.setParams({
                                    "type": "error",
                                    "message": $A.get("$Label.c.Account_and_product_with_contact_has_been_planned_already")
                                });
                                showToast.fire();
                       }
                   }
               });
               $A.enqueueAction(action1);
               
               //END:
           }else{
                   var accId = BDWrapper[indVal].objAccount.Id;
                   if(accId != 'blank' || accId!=null){
                       if(selectedAccountGetFromEvent!= null ){
                           component.set("v.selectedContactId",selectedAccountGetFromEvent.Id);
                           var action = component.get("c.getContactInfo");
                           action.setParams({
                               'contactId': selectedAccountGetFromEvent.Id,
                               'accountId' : accId 
                           });
                           action.setCallback(this,function(response){
                               
                               if(response.getState()==='SUCCESS'){
                                   
                                   var result = response.getReturnValue();
                                   for(var i=0;i<BDWrapper.length;i++){
                                       
                                       if(result != null){
                                           if(i == indVal){
                                               BDWrapper[indVal].objcontact = result;
                                               BDWrapper[indVal].ConId = result.Id;
                                               BDWrapper[indVal].AccId = accId;
                                               component.set("v.lstBDTrackerWrapper",BDWrapper);
                                           }
                                           
                                       }
                                   }
                               }
                           });
                           $A.enqueueAction(action);
                       }
                   }else{
                       
                       var showToast = $A.get("e.force:showToast");
                       showToast.setParams({
                           "type": "error",
                           "message": $A.get("$Label.c.Please_select_account_first")
                       });
                       showToast.fire();
                   }
            }
           
       }else{
           var accId;
            var contactidtocheck;
            if(BDWrapper[indVal].objAccount !=null){
                accId = BDWrapper[indVal].objAccount.Id;//component.get("v.selectedAccountId");
                contactidtocheck = component.get("v.selectedLookUpContact");
            }else{
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Please_select_account_first")
                });
                showToast.fire(); 
            }
            if(accId !='blank' && accId != null ){
               
                if(contact != null ){
                if(selectedAccountGetFromEvent!= null ){
                    
                    component.set("v.selectedProductId",selectedAccountGetFromEvent.Id);
                    component.set("v.selectedProductIdcheck",selectedAccountGetFromEvent.Id);
                    var action = component.get("c.getProductInfo");
                    
                    
                    action.setParams({
                        'productId': selectedAccountGetFromEvent.Id,
                        'accountId' : BDWrapper[indVal].objAccount.Id,
                        'contactId':contact
                    });
                    action.setCallback(this,function(response){
                        
                        if(response.getState()==='SUCCESS'){
                            
                            var result = response.getReturnValue();
                          
                            if(result != null){
                                for(var i=0;i<BDWrapper.length;i++){
                                    
                                    if(result != null){
                                        if(i == indVal){
                                            BDWrapper[indVal].objProduct = result;
                                            component.set("v.lstBDTrackerWrapper",BDWrapper);
                                         }
                                    }
                                }
                            }else{
                               var cmpValue = component.find('customLookupproduct');
                                if(cmpValue.length > 0){
                                    var len = cmpValue.length;
                               		component.find('customLookupproduct')[len-1].callChild();     
                                }else{
                                   cmpValue.callChild();      
                                }
                               
                                for(var i=0;i<BDWrapper.length;i++){
                                    if(i == indVal){
                                        BDWrapper[indVal].objProduct = null;
                                        component.set("v.lstBDTrackerWrapper",BDWrapper);
                                    }
                                }
                                var showToast = $A.get("e.force:showToast");
                                showToast.setParams({
                                    "type": "error",
                                    "message": $A.get("$Label.c.Account_and_product_with_contact_has_been_planned_already") 

                                });
                                showToast.fire();
                                
                            }
                        }
                    
                    });
                    $A.enqueueAction(action);
                }
            }
            }else{
                 var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Please_select_account_first") 
                });
                showToast.fire();
            }
        }
        }
    },
    
    saveBDTracker : function(component,event,helper,isSubmit){
         console.log('Helper ');
        component.set('v.isSubmit',false);
        var admin = component.get('v.adminVal');
        var validRecord = true;
        var action = component.get("c.BDTrackerSave");
        var wrapper = component.get("v.lstBDTrackerWrapper");
        var mont = component.get('v.selectedMonth');
        var  month = mont.split(' ');
        
        // START :Check if the selected month having only 15 Plans.
          if(wrapper.length > 15 && (!$A.util.isUndefinedOrNull(wrapper))){
              console.log('Wrapper lenght',wrapper.length > 15);
              validRecord =false;
              var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.You_can_do_max_15_plan_in_each_month")
                    });
                    showToast.fire();
              return;
          }
        
        //ENd :
        if(wrapper==null || wrapper.length <= 0){
            console.log('Wrapper null');
            validRecord =false;
            var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.No_Records_to_save")
                });
                showToast.fire();
        }
        
        if(validRecord){
            console.log('Valid records',validRecord);
            for(var i=0;i<wrapper.length;i++){
                if(wrapper[i]!=null){
                      console.log('1rd else');
                    console.log('Wrapper null');
                    if($A.util.isUndefinedOrNull(wrapper[i].objAccount) || wrapper[i].objAccount.length==0){
                        var cmpValue = component.find('customLookupid');
                        if(cmpValue.length > 0){
                            var len = cmpValue.length;
                            component.find('customLookupid')[len-1].callChildFocus();     
                        }else{
                            cmpValue.callChildFocus();      
                        }
                        validRecord =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Account_name_is_required")
                        });
                        showToast.fire();
                        
                    }else if($A.util.isUndefinedOrNull(wrapper[i].objcontact) || wrapper[i].objcontact.length == 0){
                          console.log('2rd else');
                        console.log('Wrapper Object lenght',wrapper[i].objcontact.length);
                        var cmpValue = component.find('customLookupcontact');
                        if(cmpValue.length > 0){
                            console.log('CmpValue lenght',cmpValue.length);
                            var len = cmpValue.length;
                            component.find('customLookupcontact')[len-1].callChildFocus();     
                        }else{
                            console.log('Cmp else part');
                            cmpValue.callChildFocus();      
                        }
                        validRecord =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Contact_name_is_required")
                        });
                        showToast.fire();
                        
                    } else if($A.util.isUndefinedOrNull(wrapper[i].objProduct) || wrapper[i].objProduct.length == 0){
                        console.log('3rd else');
                        var cmpValue = component.find('customLookupproduct');
                        if(cmpValue.length > 0){
                            var len = cmpValue.length;
                            component.find('customLookupproduct')[len-1].callChildFocus();     
                        }else{
                            cmpValue.callChildFocus();      
                        }
                        validRecord =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Product_name_is_required")
                        });
                        showToast.fire();
                        
                    }else if( (wrapper[i].objAccount!=null) && (wrapper[i].AccId != wrapper[i].objAccount.Id && wrapper[i].AccId!=null)){
                          console.log('4rd else');
                        validRecord =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Account_and_Contact_are_not_matched") 
                        });
                        showToast.fire();
                    }              
                    
                        else if(wrapper[i].ProdWeek == '--None--' || wrapper[i].ProdYear == '--None--'){
                              console.log('5trd else');
                            validRecord =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Please_select_Product_Discussion_Week.") 
                            });
                            showToast.fire();
                        }else  if(wrapper[i].EvalWeek == '--None--' || wrapper[i].EvalYear == '--None--' || wrapper[i].EvalYear==''|| wrapper[i].EvalWeek ==''){
                            console.log('6trd else');
                            validRecord =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Please_select_Evaluation_Week.") 
                            });
                            showToast.fire();
                        }else  if(wrapper[i].CommWeek == '--None--' || wrapper[i].CommYear == '--None--' || wrapper[i].CommYear==''|| wrapper[i].CommWeek ==''){
                            console.log('7trd else');
                            validRecord =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Please_select_Commercialization_Week.")
                            });
                            showToast.fire();
                        } 
                }
            }
        }
       
        if(validRecord){
            console.log('3rd valid records',validRecord);
            for(var i=0;i<wrapper.length;i++){
                for(var k=i+1;k<wrapper.length;k++){
                    console.log('Test data');
                    console.log('Wrapper Account'+wrapper[i].objAccount);
                    if(wrapper[i].objAccount!=null){
                        console.log('Wrapper Account'+wrapper[i].objAccount);
                        if(wrapper[i].objAccount.Id ==wrapper[k].objAccount.Id && wrapper[i].objProduct.Id == wrapper[k].objProduct.Id &&
                           wrapper[i].objcontact.Id == wrapper[k].objcontact.Id){
                            
                            validRecord =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Account_and_product_with_contact_has_been_planned_already")
                            });
                            showToast.fire();
                        }
                    }
                }
            }
        }
        //START :Chcek the next 3 months entrys are avaibale or not.
        if(validRecord){
           // alert(component.get('v.userInfo').Id);
            console.log('Test data2');
            component.set('v.isShowSpinner',true);
            console.log('Spinner true');
            var action2 = component.get('c.validatePlans');
            console.log('Action Plans',action2);
            action2.setParams({
                'objStr':JSON.stringify(wrapper),
                'isSubmit':isSubmit,
                'Month':month[0],
                'year':component.get('v.selectedYear')
            });
            action2.setCallback(this,function(response){
                if(response.getState()==='SUCCESS'){
                    console.log('Response state',response.getState());
                    if(response.getReturnValue()){ 
                        console.log('Return Value',response.getReturnValue());
                        action.setParams({
                            'objStr':JSON.stringify(wrapper),
                            'isSubmit':isSubmit,
                            'Month':month[0],
                            'userIdValue':component.get('v.userInfo').Id,
                            'selectedYear' :component.get('v.selectedYear')
                        });
                        action.setCallback(this,function(response){
                            
                            if(response.getState()==='SUCCESS'){
                                console.log('State2',response.getState());
                                this.getRecords(component,event,helper);
                                var result = response.getReturnValue();
                                console.log('Success result',result);
                                component.set('v.isShowSpinner',false);
                                if(result.length > 0){ 
                                    console.log('result lenght',result.length );
                                    if(isSubmit){
                                        console.log('submit data',isSubmit);
                                        component.set('v.isReplanRequest',true);
                                        if((!admin)){
                                            console.log('Admin',admin);
                                            component.set('v.isSubm',true);
                                            component.set('v.isOpenRequest',false);
                                        }else{
                                            console.log('Admins',admin);
                                            component.set('v.isSubm',false); 
                                            component.set('v.isOpenRequest',true);
                                        }
                                        
                                        var showToast = $A.get("e.force:showToast");
                                        console.log('showToast',showToast);
                                        showToast.setParams({
                                            "type": "success",
                                            "message": $A.get("$Label.c.BD_Tracker_has_been_Submitted")
                                        });
                                        showToast.fire();
                                    }else{
                                        var showToast = $A.get("e.force:showToast");
                                        showToast.setParams({
                                            "type": "success",
                                            "message": $A.get("$Label.c.BD_Tracker_has_been_saved")
                                        });
                                        showToast.fire();
                                    }
                                    
                                    component.set('v.lstBDTrackerWrapper',result)
                                  console.log(result);
                                    var resultSize = result.length;
                                    var len = resultSize-1;
                                    
                                    if((!$A.util.isUndefinedOrNull(result[len].lstWeeksOfYear))){ 
                                        for(var k = 0; k< result[len].lstWeeksOfYear.length;k++){
                                            
                                            if(result[len].lstWeeksOfYear[k].split(' ')[0] == month[0]){
                                                
                                                component.set('v.selectedMonth',result[len].lstWeeksOfYear[k]);
                                                break;
                                            }
                                        }
                                        
                                        component.set('v.lstMonths',result[len].lstWeeksOfYear);
                                    }
                                    
                                }else{
                                    component.set('v.isShowSpinner',false);
                                    var showToast = $A.get("e.force:showToast");
                                    showToast.setParams({
                                        "type": "error",
                                        "message": $A.get("$Label.c.Something_went_wrong")
                                    });
                                    showToast.fire();
                                    console.log('Error Occurred.');
                                    component.set('v.isSubm',false);
                                    component.set('v.isOpenRequest',true);
                                }
                            }
                        });
                        $A.enqueueAction(action);
                        
                        //End
                    }else{
                     
                        if(component.get('v.isOpenRequest')){
                            component.set('v.isOpenRequest',true);
                        }else if(!component.get('v.isOpenRequest')){
                           component.set('v.isOpenRequest',false);
                        }  
                        component.set('v.isSubm',false); 
                        
                        
                        component.set('v.isShowSpinner',false);
                        
                        validRecord =false;  
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Account_and_product_with_contact_has_been_planned_already")
                        });
                        showToast.fire(); 
                    }
                }
                
            });
            $A.enqueueAction(action2); 
        }
        
        //END
        
      
        
    },
    addNewRow : function(component,event,helper){
        //debugger;
        this.defaultWeeks(component,event,helper,null);
        component.set("v.selectedAccountIdcheck",null);
        component.set("v.selectedContactIdcheck",null);
        component.set("v.selectedProductIdcheck",null);  
        
        //component.set('v.noDataFound',false);
        var curntWeek = component.get('v.currentWeek');
        var validRecord = true;
        var BDWrap = component.get('v.lstBDTrackerWrapper');
        //;
        if(BDWrap.length < 15 && (!$A.util.isUndefinedOrNull(BDWrap))){
            for(var i=0;i<BDWrap.length;i++){
                
                if(BDWrap[i].objAccount==null || BDWrap[i].objAccount.length==0){
                    validRecord =false;
                    var cmpValue = component.find('customLookupid');
                    if(cmpValue.length > 0){
                        var len = cmpValue.length;
                        component.find('customLookupid')[len-1].callChildFocus();     
                    }else{
                        cmpValue.callChildFocus();      
                    }
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Account_name_is_required")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].objcontact==null || BDWrap[i].objcontact.length==0){
                    
                    var cmpValue = component.find('customLookupcontact');
                    if(cmpValue.length > 0){
                        var len = cmpValue.length;
                        component.find('customLookupcontact')[len-1].callChildFocus();     
                    }else{
                        cmpValue.callChildFocus();      
                    }
                    
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Contact_name_is_required")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].objProduct==null || BDWrap[i].objProduct.length==0){
                    validRecord =false;
                    var cmpValue = component.find('customLookupproduct');
                    if(cmpValue.length > 0){
                        var len = cmpValue.length;
                        component.find('customLookupproduct')[len-1].callChildFocus();     
                    }else{
                        cmpValue.callChildFocus();      
                    }
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Product_name_is_required")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].ProdYear=='--None--'){
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Please_select_Product_Discussion_Year")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].EvalYear=='--None--'){
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Please_select_Evaluation_Year.")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].CommYear=='--None--'){
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Please_select_Commercialization_Year.")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].ProdWeek=='--None--' || BDWrap[i].ProdWeek==''){
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Please_select_Product_Discussion_Week")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].EvalWeek=='--None--'|| BDWrap[i].EvalWeek==''){
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Please_select_Evaluation_Week")
                    });
                    showToast.fire();
                    
                }else if(BDWrap[i].CommWeek=='--None--'|| BDWrap[i].CommWeek==''){
                    validRecord =false;
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Please_select_Commercialization_Week")
                    });
                    showToast.fire();
                    
                }
                
            }
            if(validRecord){
                //debugger;
               var action = component.get("c.monthWiseWeeks");
               var mont = component.get('v.selectedMonth');
               var  month = mont.split(' ');
                action.setParams({'year':component.get('v.selectedYear'),
                                  'month':month[0]});
                action.setCallback(this,function(response){
                    if(response.getState()==='SUCCESS'){
                        var result = response.getReturnValue();
                       component.set('v.lstProdWeeks',result);
                        var ls =[];
                        var yr =[];
                        yr.push('2019');yr.push('2020');yr.push('2021');yr.push('2022');yr.push('2023');yr.push('2024');yr.push('2025');
                        yr.push('2026');yr.push('2027');yr.push('2028');yr.push('2029');yr.push('2030');
                        ls.push($A.get("$Label.c.Product_Discussion")); 
                        ls.push($A.get("$Label.c.Evaluation"));
                        ls.push($A.get("$Label.c.Commercialization"));  
                        ls.push(yr);
                        var stg=[];
                        stg.push({
                            'stageName':$A.get("$Label.c.Product_Discussion"), 
                            'lstYears':null,
                            'lstWeeks':result
                        });
                        stg.push({
                            'stageName':$A.get("$Label.c.Evaluation"), 
                            'lstYears':null,
                            'lstWeeks':null
                        });
                        stg.push({
                            'stageName':$A.get("$Label.c.Commercialization"), 
                            'lstYears':null,
                            'lstWeeks':null
                        });
                        
                        
                        BDWrap.push({
                            'objAccount':null,
                            'lstStages':stg,
                            'objProduct':null,
                            'ProdWeek':month[0].split('-')[0],//curntWeek,//result[0],
                            'EvalWeek':'',
                            'CommWeek':'',
                            'ProdYear':component.get('v.selectedYear'),
                            'EvalYear':component.get('v.selectedYear'),
                            'CommYear':component.get('v.selectedYear'),
                            'objcontact':null,
                            'Status':$A.get('$Label.c.New'), 
                            'isDisabled':false
                            
                        });
                       
                       
                        component.set('v.lstBDTrackerWrapper',BDWrap);
                        var cmpValue = component.find('customLookupid');
                                if(cmpValue.length > 0){
                                    var len = cmpValue.length;
                               		component.find('customLookupid')[len-1].callChildFocus();     
                                }else{
                                   cmpValue.callChildFocus();      
                                }
                       
                    } 
                });
                $A.enqueueAction(action);
                
            }
        }else{
            var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.You_have_reached_plan_limit_for_the_current_month")
                    });
                    showToast.fire();
            
        }
        
    },
    deleteLastRow : function(component,event,helper){
        var wrap = component.get('v.lstBDTrackerWrapper');
        
        if(wrap.length > 1){
            wrap.pop();
            component.set('v.lstBDTrackerWrapper',wrap);
        }
        
    },
    getRecords:function(component, event, helper) {
        var admin = component.get('v.adminVal');
        
        this.defaultWeeks(component, event, helper,null);
        this.validateSelectedWeek(component, event, helper);
        var yearv = component.get('v.selectedYear'); 
        var mont = component.get('v.selectedMonth');
        var  monthv = mont.split(' ');
        debugger;
        if((!$A.util.isUndefinedOrNull(yearv)) &&(!$A.util.isUndefinedOrNull(monthv[0]))
           && yearv !='--None--' && monthv[0]!='--None--'){
            
            var action = component.get("c.monthWiseWeeks");
            action.setParams({'year':component.get('v.selectedYear'),
                              'month':monthv[0]
                             });
            action.setCallback(this,function(response){
                if(response.getState()==='SUCCESS'){
                    var result = response.getReturnValue();
                    
                    component.set('v.lstProdWeeks',result);
                    
                    var action1 = component.get("c.getBDTrackerByYearandMonth");
                  
                    action1.setParams({
                        'year':yearv,
                        'month':monthv[0],
                        'uID' :component.get('v.userId')
                    });
                   // debugger;
                    action1.setCallback(this,function(response){
                        if(response.getState()==='SUCCESS'){
                            component.set('v.isShowSpinner',false);
                            
                            var result = response.getReturnValue()
                            if(result.length>0){
                               
                                
                               // component.set('v.noDataFound',false);
                                component.set('v.lstBDTrackerWrapper',result);
                                var resultSize = result.length;
                                    var len = resultSize-1;
                                    
                                    if((!$A.util.isUndefinedOrNull(result[len].lstWeeksOfYear))){ 
                                        for(var k = 0; k< result[len].lstWeeksOfYear.length;k++){
                                            
                                            if(result[len].lstWeeksOfYear[k].split(' ')[0] == monthv[0]){
                                                
                                                component.set('v.selectedMonth',result[len].lstWeeksOfYear[k]);
                                                break;
                                            }
                                        }
                                   
                                   //Check if Selected year is next year.
                                    if(parseInt(yearv)==new Date().getFullYear()){
                                        component.set('v.currentYearWeeks',result[len].lstWeeksOfYear);
                                    }
                                    component.set('v.lstMonths',result[len].lstWeeksOfYear);
                                    
                                }
                                if(admin){
                                    component.set('v.isSubm',false);
                                    component.set('v.isOpenRequest',true)
                                }else{
                                    
                                    var userDetail = component.get('v.userInfo');
                                    if($A.util.isUndefinedOrNull(userDetail.Rsm_User__c) || $A.util.isUndefinedOrNull(userDetail.ManagerId)){
                                        
                                    }else{
                                        component.set('v.isRSMAdded',false); 
                                    }
                                }
                                
                            }else{
                               component.set('v.lstBDTrackerWrapper',[]); 
                             if(!component.get('v.isOpenRequest'))
                                 
                               component.set('v.isReplanRequest',false);
                            }
                           
                        }
                    });
                    $A.enqueueAction(action1);
                    
                } 
            });
            $A.enqueueAction(action);  
            
            
        }else{
            var showToast = $A.get("e.force:showToast");
            showToast.setParams({
                "type": "error",
                "message": $A.get("$Label.c.Please_select_year_and_Week")
            });
            showToast.fire();
        }
    },
    ValidateMonthVal :function(component, event, helper){
        this.getWeeksOfYearValue(component, event, helper,null,null);
       
    },
    validateSelectedWeek:function(component,event,helper){
        
        var mont = component.get('v.selectedMonth');
        var  selectedW = mont.split(' ');
        var selectedY= component.get('v.selectedYear');
        var yearToCheck = selectedW[0].split('-');
        var currentWeekValue = component.get('v.currentWeek');
        if(parseInt(selectedY) < new Date().getFullYear()){
            component.set('v.isOldMonth',true);    
        }else if(parseInt(selectedY) == new Date().getFullYear() && yearToCheck[1] < currentWeekValue){
            component.set('v.isOldMonth',true);
        }else{
            component.set('v.isOldMonth',false);
        }
        
    },
    getLockSubmit :function(component,event,helper){
        var selectedWeekRange = component.get('v.selectedMonth');
        var  month = selectedWeekRange.split(' ');
        
        var action = component.get('c.getLockSubmitValues');
       var admin = component.get('v.adminVal');
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
                
                if(response.getReturnValue()){
                    if(!admin){
                        component.set('v.isSubm',true);
                    }
                    
                }else{
                    component.set('v.isSubm',false);
                }
                
            }
        });
        $A.enqueueAction(action);
    },
   
    makeReSubmitRequest :function(component,event,helper){
        var admin = component.get('v.adminVal');
        var range = component.get('v.selectedMonth').split(' ')[0];
        
        var action = component.get('c.callApproval');
        action.setParams({
            "Month":range,
            "selYear" :component.get('v.selectedYear')
       });
       action.setCallback(this,function(response){
           
            if(response.getState()==='SUCCESS'){
                
                if(response.getReturnValue() != null){
                    component.set("v.BDTHistory", response.getReturnValue());
                    component.set("v.isOpenRequest", true);
                    component.set("v.isRequestToSubmit", false);
                    component.set('v.approveReject',false);
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "success",
                        "message": $A.get("$Label.c.You_have_requested_Re_Submission.")
                    });
                    showToast.fire();
                    
                    
                }else{
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.You_have_already_requested_for_Re_Submission")
                    });
                    showToast.fire();
                    
                    
                    component.set("v.isOpenRequest", true);
                  
                    component.set("v.isRequestToSubmit", false);
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    updateRequestToSubmit :function(component,event,helper){
        var admin = component.get('v.adminVal');
        var range = component.get('v.selectedMonth').split(' ')[0];
        var selectedYr = component.get('v.selectedYear');        
        var action = component.get('c.updateforSubmitRequest');
        action.setParams({
            "Month":range,
            "selYear" :selectedYr
        });
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
                
                var result = response.getReturnValue();
                if(!admin){
                    debugger;
                    if(result != null)
                    { 
                          component.set('v.BDTHistory',result);
                           if(result.Request_for_Reopen__c && result.isSubmitted__c && result.WeekRange__c== range &&
                             result.Year__c==selectedYr) {  
                               
                                component.set('v.isOpenRequest',true);
                                component.set('v.isSubm',true);
                                component.set('v.isReplanRequest',true); 
                                
                            }else if(result.Request_for_Reopen__c==false && result.isSubmitted__c && result.WeekRange__c== range &&
                             result.Year__c==selectedYr){
                                
                               component.set('v.isOpenRequest',false);
                               component.set('v.isSubm',true);
                               component.set('v.isReplanRequest',true); 
                            }else if(result.Request_for_Reopen__c==false && result.isSubmitted__c ==false && result.WeekRange__c== range &&
                             result.Year__c==selectedYr){
                                
                               component.set('v.isOpenRequest',true);
                               component.set('v.isSubm',false);
							   component.set('v.isReplanRequest',false); 
                                
                            }
                        
                        component.set('v.reOpenStatus',false)
                    }else if(result==null){
                        
                        component.set('v.isOpenRequest',true);
                        component.set('v.isSubm',false);
                        component.set('v.reOpenStatus',true)
                    }
                    
                }else{
                    component.set('v.isOpenRequest',true);
                    component.set('v.isSubm',false); 
                    component.set('v.isReplanRequest',false);
                } 
            } 
        });
        $A.enqueueAction(action);
    },
    getNextYearWeekRange : function(component,event,helper){
        var action = component.get('c.getWeekssOfyear');
        var nextYear = parseInt(component.get('v.selectedYear'))+1;
        action.setParams({"year":nextYear});
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
                
                component.set('v.nextYearWeeks',response.getReturnValue());
            } 
        });
        $A.enqueueAction(action);
    },
    RSMApprovalforSubmit:function(component,event,helper){
        
        var action = component.get('c.checkApprovalPending');
        var range = component.get('v.selectedMonth').split(' ')[0];
        action.setParams({
            "uID":component.get("v.userId"),
           "Month":range,
           "selYear" :component.get('v.selectedYear')
         });
        action.setCallback(this,function(response){
            
            if(response.getState()==='SUCCESS'){
                //alert(response.getReturnValue())
                if(response.getReturnValue()){ 
                    component.set('v.approveReject',false); 
                }else{
                    component.set('v.approveReject',true);  
                } 
            }
        });
        $A.enqueueAction(action);
    },
})