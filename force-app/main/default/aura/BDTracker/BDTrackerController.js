({
    doInit : function(component, event, helper) {
        debugger;
        //START :
       var params =helper.getURLParameterValue();
        console.log('params',params);
        var idParamValue,PlanValue ;
        if(!$A.util.isUndefinedOrNull(params)){
            idParamValue = helper.getURLParameterValue().c__UID;
            PlanValue = helper.getURLParameterValue().c__gotoPlan;
            console.log('idParamaValue--',idParamValue);
            console.log('PlanValue--',PlanValue);
        }
        component.set("v.userId", idParamValue);
        
        if(!$A.util.isUndefinedOrNull(idParamValue)){
            component.set('v.isGoToPlan',true); 
            console.log('Null data',idParamValue);
        }
        
        component.set('v.isShowSpinner',true);
        var wk=[];
        for(var i=1;i<=53;i++){
            wk.push(i); 
        }
        
        component.set('v.lstEvalWeeks',wk);
        component.set('v.lstCommWeeks',wk); 
        
        var yr = new Date().getFullYear()
        console.log('Year data----',yr);
        component.set("v.selectedYear",yr.toString());
        var action = component.get("c.getPickListValuesIntoList");
        console.log('Action data',action);
        action.setParams({"userId":idParamValue});
        
        action.setCallback(this,function(response){
            console.log('response data',response);
            console.log('get error',response.getError());
            if(response.getState()==='SUCCESS'){
                console.log('Sucess data',response.getState());
                
                debugger;
                var result =response.getReturnValue();
                console.log('result',result);
                component.set('v.lstProdYear',response.getReturnValue()[0].lstStages[0].lstYears);
                component.set('v.lstEvalYear',response.getReturnValue()[0].lstStages[0].lstYears);
                component.set('v.lstCommYear',response.getReturnValue()[0].lstStages[0].lstYears);
                
                component.set('v.lstYears',response.getReturnValue()[0].lstStages[0].lstYears);
                component.set('v.currentWeek',response.getReturnValue()[0].currentWeek);
                component.set('v.isRSM',response.getReturnValue()[0].isRSMUser);
                component.set('v.userInfo',response.getReturnValue()[0].loggedInUserName);
                console.log('response data',response.getReturnValue()[0].loggedInUserName);
                //alert(response.getReturnValue()[0].isAdmin)
                component.set('v.adminVal',response.getReturnValue()[0].isAdmin);
                var yr = new Date().getFullYear()
                console.log('year--',yr);
                component.set("v.selectedYear",yr.toString());
                
                
              
            } 
        });
        $A.enqueueAction(action); 
        debugger;
        helper.getNextYearWeekRange(component,event,helper);
        if(!$A.util.isUndefinedOrNull(idParamValue) && !$A.util.isUndefinedOrNull(PlanValue)){
            helper.getWeeksOfYearValue(component, event, helper,idParamValue,PlanValue);
        }else{
          helper.getWeeksOfYearValue(component, event,helper);  
        }
           
    },
    
    getAccount : function(component, event, helper) {
        
        var action = component.get("c.getAccountDetails");
        action.setParams({"strInput" :component.get("v.SearchKey")});
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
                var result = response.getReturnValue();
                if(result.length > 0){
                   // component.set("v.recFound",true);
                    //component.set("v.lstAccounts",result);
                }
                else{
                    //component.set("v.recFound",false);
                    
                }
                
                
            } 
        });
        $A.enqueueAction(action); 
    },
    getWeeks : function(component, event, helper) {
        var mont = component.get('v.selectedMonth');
        var  month = mont.split(' ');
        var selYear = component.get('v.selectedYear');
        var lststr = month[0].split('-');
        
        //var action = component.get("c.getWeeksOfYear");
        
        var yearVal = event.getSource().get('v.value');
        var BDWrap = component.get('v.lstBDTrackerWrapper');
        var selectedYr = component.get('v.selectedYear');
        var isSuccess =true;
        for(var i=0;i<BDWrap.length;i++){
            
            if((BDWrap[i].ProdYear!= '' && BDWrap[i].EvalYear!= '') && (BDWrap[i].ProdYear!= '--None--' && BDWrap[i].EvalYear!= '--None--') && (BDWrap[i].ProdYear > BDWrap[i].EvalYear )){
                isSuccess =false;
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message":$A.get("$Label.c.Product_Discussion_year_can_not_be_more_than_Evaluation_year")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('oldValue'));
            }else if((BDWrap[i].ProdYear!= '' && BDWrap[i].CommYear!= '') &&(BDWrap[i].ProdYear!= '--None--' && BDWrap[i].CommYear!= '--None--') && (BDWrap[i].ProdYear > BDWrap[i].CommYear )){
                isSuccess =false;
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Product_Discussion_year_can_not_be_more_than_commercialization_year")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('oldValue'));
            }else if((BDWrap[i].EvalYear!= '' && BDWrap[i].CommYear!= '') && (BDWrap[i].EvalYear!= '--None--' && BDWrap[i].CommYear!= '--None--') && (BDWrap[i].EvalYear > BDWrap[i].CommYear )){
                isSuccess =false;
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Evaluation_year_can_not_be_more_than_commercialization_year")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('oldValue'));
            }else if(BDWrap[i].ProdYear == '' && BDWrap[i].ProdYear == '--None--' && (BDWrap[i].EvalYear !='--None--' || BDWrap[i].CommYear != '--None--')&& (BDWrap[i].EvalYear !='' || BDWrap[i].CommYear != '')){
                isSuccess =false;
                event.getSource().set('v.value',event.getParam('v.oldValue'));
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "warning",
                    "message": $A.get("$Label.c.Product_Discussion_year_must_be_provided")
                });
                showToast.fire();
            } else if(BDWrap[i].EvalYear =='--None--' && BDWrap[i].EvalYear ==''  && (BDWrap[i].CommYear != '--None--') && (BDWrap[i].CommYear != '')){
                isSuccess =false;
                
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "warning",
                    "message": $A.get("$Label.c.Evaluation_year_must_be_provided")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getSource('v.oldValue'));
                
            }else if( BDWrap[i].EvalYear != '' && BDWrap[i].EvalYear != '--None--' && (BDWrap[i].ProdYear == '--None--') && (BDWrap[i].ProdYear == '')){
                isSuccess =false;
                
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "warning",
                    "message": $A.get("$Label.c.Product_Discussion_year_must_be_provided")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getSource('v.oldValue'));
            }
        }
        
        
        if(isSuccess){
           helper.defaultWeeks(component,event,helper,event.getSource().get('v.value')); 
         /*   action.setParams({
                'year':event.getSource().get('v.value'),
                'month':lststr[0],
                'slYear':selYear
            });
            
            action.setCallback(this,function(response){
                if(response.getState()==='SUCCESS'){
                    
                    var prodWeek = component.get('v.lstProdWeeks');
                    
                    var evalWeek = component.get('v.lstEvalWeeks');
                    var commWeek = component.get('v.lstCommWeeks');
                    
                    var wk=[];
                    for(var i=1;i<=53;i++){
                        wk.push(i); 
                    }
                    var result = response.getReturnValue();
                    for(var key in result){
                        //alert(result[key])
                        for(var i=0;i<BDWrap.length;i++){
                            
                            if(event.getSource().get('v.label')==i+'prodYear'){
                                component.set('v.lstProdWeeks',result[key]);
                            }else if(event.getSource().get('v.label')==i+'evalYear'){
                                component.set('v.lstEvalWeeks',result[key]);
                            }else if(event.getSource().get('v.label')==i+'commYear'){
                                component.set('v.lstCommWeeks',result[key]);
                            }
                        } 
                    }
                    
                }
            });
            $A.enqueueAction(action);
        }   */
        }
    },
    
    checkWeeks : function(component, event, helper) {
        
        var prodw = component.get('v.lstProdWeeks');
        var curntWeek = component.get('v.currentWeek');
        var BDWrap = component.get('v.lstBDTrackerWrapper');
        for(var i=0;i<BDWrap.length;i++){
            /*   if(parseInt(BDWrap[i].ProdWeek) < curntWeek){
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": "Product Discussion Week should not be less than current week."
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }
            if(parseInt(BDWrap[i].EvalWeek) < curntWeek){
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": "Evaluation Week should not be less than current week."
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }
            if(parseInt(BDWrap[i].CommWeek) < curntWeek){
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": "Commercialization Week should not be less than current week."
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }*/
            if(parseInt(BDWrap[i].ProdWeek) > parseInt(BDWrap[i].EvalWeek) && BDWrap[i].EvalWeek != '--None--' && BDWrap[i].ProdYear == BDWrap[i].EvalYear){
                
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Product_Discussion_Week_should_not_be_more_than_Evaluation_week")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }else if(parseInt(BDWrap[i].ProdWeek) > parseInt(BDWrap[i].CommWeek) && BDWrap[i].CommWeek != '--None--' && BDWrap[i].ProdYear == BDWrap[i].CommYear){
                
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Product_Discussion_Week_should_not_be_more_than_Commercialization_week")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }else if(parseInt(BDWrap[i].EvalWeek) < parseInt(prodw[0]) && BDWrap[i].EvalYear < BDWrap[i].ProdYear){
                
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Evaluation_Week_should_not_be_previous_month_week")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }else if(parseInt(BDWrap[i].CommWeek) < parseInt(prodw[0]) && BDWrap[i].CommYear < BDWrap[i].ProdYear){
                
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "error",
                    "message": $A.get("$Label.c.Evaluation_Week_should_not_be_previous_month_week")
                });
                showToast.fire();
                event.getSource().set('v.value',event.getParam('v.oldValue'));
            }
                else if(parseInt(BDWrap[i].EvalWeek) > parseInt(BDWrap[i].CommWeek) && BDWrap[i].CommWeek != '--None--' && BDWrap[i].EvalYear == BDWrap[i].CommYear){
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Evaluation_Week_should_not_be_more_than_Commercialization_week")
                    });
                    showToast.fire();
                    event.getSource().set('v.value',event.getParam('v.oldValue'));
                }else if(BDWrap[i].ProdWeek == '--None--' && (BDWrap[i].EvalWeek != '--None--' || BDWrap[i].CommWeek!='--None--')){
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Product_discussion_week_must_be_provided")
                    });
                    showToast.fire();
                    event.getSource().set('v.value',event.getParam('v.oldValue'));
                }else if(BDWrap[i].EvalWeek == '--None--' && BDWrap[i].CommWeek!='--None--'){
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Evaluation_week_must_be_provided")
                    });
                    showToast.fire();
                    event.getSource().set('v.value',event.getParam('v.oldValue'));
                }else if(BDWrap[i].EvalWeek != '--None--' && BDWrap[i].ProdWeek =='--None--'){
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Product_discussion_week_must_be_provided")
                    });
                    showToast.fire();
                    event.getSource().set('v.value',event.getParam('v.oldValue'));
                }else if(BDWrap[i].CommWeek != '--None--' && (BDWrap[i].ProdWeek =='--None--'|| BDWrap[i].EvalWeek== '--None--')){
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "error",
                        "message": $A.get("$Label.c.Product_Discussion_and_Evaluation_week_must_be_provided")
                    });
                    showToast.fire();
                    event.getSource().set('v.value',event.getParam('v.oldValue'));
                }
        }
    },
    handleComponentEvent : function(component,event,helper) {
        helper.handleComponentEventHelper(component,event,helper);
    },
    
    savePlan :function(component,event,helper) {
       console.log('Month data',component.get('v.selectedMonth'));//code add
        var mont = component.get('v.selectedMonth');
        var  monthValue = mont.split(' ');
        if(component.get("v.isSubmit")){
            console.log('Submit data',component.get("v.isSubmit"));//code add
            component.set('v.isSubmit',true);
            //component.set('v.isOpenRequest',false);
            helper.saveBDTracker(component,event,helper,component.get("v.isSubmit"));
            
        }else{
            var isSubmit =false;
            console.log('Submit false');//Code add 
            helper.saveBDTracker(component,event,helper,isSubmit);
            var ds =[];
            
            //ftVal.push(monthValue[0]);
            
            //component.set('v.validatePlanForfuture',ftVal);
            
        }
        
    },
    addRow :function(component,event,helper) {
        helper.addNewRow(component,event,helper);
    },
    removeRow : function(component, event, helper){
        // fire the DeleteRowEvt Lightning Event and pass the deleted Row Index to Event parameter/attribute
        //alert();
        component.getEvent("DeleteRowEvt").setParams({"indexVar" : event.currentTarget.dataset.ind }).fire();
    }, 
    cancelPlan : function(component,event,helper){
        window.location.href = "/lightning/page/home";
    },
    removeDeletedRow: function(component, event, helper) {
        var AllRowsList = component.get("v.lstBDTrackerWrapper");
        var mont = component.get('v.selectedMonth');
        var  monthv = mont.split(' ');
        var i = component.get("v.indexValue");
        
        if(component.get('v.reasonForDelete')!=null){
            component.set("v.isModalOpen", false);
            component.set('v.isShowSpinner',true);
            var action =component.get("c.deleteBDTracker");
            action.setParams({
                'jsonstr':JSON.stringify(AllRowsList[i]),
                'deleteReason':component.get('v.reasonForDelete'),
                'year':component.get('v.selectedYear'),
                'usr':component.get("v.userId")
            });
            action.setCallback(this,function(response){
                if(response.getState()==='SUCCESS'){
                    component.set('v.isShowSpinner',false);
                    var result = response.getReturnValue();
                    //START :
                    for(var k = 0; k < result.length;k++){
                        
                        if(result[k].split(' ')[0] == mont.split(' ')[0]){
                            
                            component.set('v.selectedMonth',result[k]);
                            break;
                        }
                    }
                    component.set('v.lstMonths',result);
                    
                    //END:
                    
                    var showToast = $A.get("e.force:showToast");
                    showToast.setParams({
                        "type": "success",
                        "message": $A.get("$Label.c.BD_plan_has_been_deleted")
                    });
                    showToast.fire(); 
                    component.set('v.reasonForDelete',null);
                    
                    AllRowsList.splice(i, 1);
                    
                    //component.set("v.isModalOpen", false);
                    
                    component.set("v.lstBDTrackerWrapper", AllRowsList);
                    
                    // END:
                }
            });
            $A.enqueueAction(action);
        }else if(component.get('v.reasonForDelete')==null && component.get('v.isIdAvailable')){
            var showToast = $A.get("e.force:showToast");
            showToast.setParams({
                "type": "error",
                "message": $A.get("$Label.c.Reason_for_deletion_is_required")
            });
            showToast.fire();
        }else{
            
            AllRowsList.splice(i, 1);
            component.set("v.isModalOpen", false);
            
            component.set("v.lstBDTrackerWrapper", AllRowsList);
        }
    },
    
    openRequestModel: function(component, event, helper) {
        
     component.set("v.isRequestToSubmit", true);
       
    },
    openModel: function(component, event, helper) {
       // debugger;
        component.set("v.indexValue",event.currentTarget.dataset.ind);
        component.set("v.isModalOpen", true);
        var BDTrack = component.get("v.lstBDTrackerWrapper");
        
        if(BDTrack[event.currentTarget.dataset.ind].BDrecId!=null){
            component.set('v.isIdAvailable',true);
        }
        
        
    },
    openSubmitModel: function(component, event, helper) {
        // debugger;
      console.log('Test data');
        var lstWrap = component.get("v.lstBDTrackerWrapper");
        var nextYearWeekRange = component.get('v.nextYearWeeks');
        var curWeek = component.get('v.currentWeek');
        var ftVal = [];
        var mont = component.get('v.selectedMonth');
        var  monthValue = mont.split(' ');
        var yearValue = component.get('v.selectedYear');
        var mont = component.get('v.selectedMonth');
        var  monthValue = mont.split(' ');
        var lstMonths = component.get('v.lstMonths');
        var counter=0;
        var validEntery =true;
        var currentMonth; var nxtMonth1; var nxtMonth2;
        var isCurrentMonthVal =false; var isNxtMonthVal1 =false; var isNxtMonthVal2 =false;
        var currentWeekRange;
        
        
        if(lstWrap.length >0){
            //STart: 
            
            for(var i=0;i<lstWrap.length;i++){
                if(lstWrap[i]!=null){
                    
                    if(lstWrap[i].objAccount==null){
                        validEntery =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Account_name_is_required")
                        });
                        showToast.fire();
                        
                    }else if(lstWrap[i].objcontact==null){
                        validEntery =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Contact_name_is_required")

                        });
                        showToast.fire();
                        
                    } else if(lstWrap[i].objProduct==null){
                        validEntery =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Product_name_is_required")
                        });
                        showToast.fire();
                        
                    }else if( (lstWrap[i].objAccount!=null) && (lstWrap[i].AccId != lstWrap[i].objAccount.Id && lstWrap[i].AccId!=null)){
                        validEntery =false;
                        var showToast = $A.get("e.force:showToast");
                        showToast.setParams({
                            "type": "error",
                            "message": $A.get("$Label.c.Account_and_Contact_are_not_matched")
                        });
                        showToast.fire();
                    }              
                    
                        else if(lstWrap[i].ProdWeek == '--None--' || lstWrap[i].ProdYear == '--None--'){
                            validEntery =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Product_Discussion_plan_year_and_plan_week_must_be_provided")
                            });
                            showToast.fire();
                        }else  if(lstWrap[i].EvalWeek == '--None--' || lstWrap[i].EvalYear == '--None--' || lstWrap[i].EvalYear==''|| lstWrap[i].EvalWeek ==''){
                            validEntery =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Evaluation_plan_year_and_plan_week_must_be_provided")
                            });
                            showToast.fire();
                        }else  if(lstWrap[i].CommWeek == '--None--' || lstWrap[i].CommYear == '--None--' || lstWrap[i].CommYear==''|| lstWrap[i].CommWeek ==''){
                            validEntery =false;
                            var showToast = $A.get("e.force:showToast");
                            showToast.setParams({
                                "type": "error",
                                "message": $A.get("$Label.c.Commercialization_plan_year_and_plan_week_must_be_provided")
                            });
                            showToast.fire();
                        } 
                }
            }           
            
          
            if(validEntery) {
                
                var action2 = component.get('c.validatePlans');
                action2.setParams({
                    'objStr':JSON.stringify(lstWrap),
                    'isSubmit':true,
                    'Month':monthValue[0],
                    'year':component.get('v.selectedYear')
                });
                component.set('v.isShowSpinner',true);
                action2.setCallback(this,function(response){
                    if(response.getState()==='SUCCESS'){
                        if(response.getReturnValue()){ 
                            component.set('v.isShowSpinner',false);
                            
                            validEntery =true;
                            
                            //ENd :
                            if(validEntery) {   //Validentery Start 
                                
                                if(ftVal.length == 0 || ftVal== '' || ftVal==undefined){
                                    
                                    //START :Check for Future Month 
                                    var monthlst = component.get('v.lstMonths');
                                    var nxt1month;
                                    var nxt2Month;  
                                    var curWeekRange;
                                    var selectedWeekRange;
                                    for(var p=0;p < monthlst.length;p++){
                                        
                                        var splt = monthlst[p].split(' ');
                                        var rngWeek = splt[0].split('-');
                                        if(parseInt(curWeek) >= parseInt(rngWeek[0]) && parseInt(curWeek) <= parseInt(rngWeek[1])){
                                            selectedWeekRange = monthlst[p];
                                            break;
                                        }
                                    } 
                                    
                                    // selectedWeekRange = '45-49 (1)';
                                    if( parseInt(yearValue) > (new Date().getFullYear())){
                                        
                                        var weekRange = component.get('v.currentYearWeeks');
                                        for(var p=0;p < weekRange.length;p++){
                                            if(weekRange[p] == selectedWeekRange)
                                            {
                                                if(!($A.util.isUndefinedOrNull(selectedWeekRange.split(' ')[1])) && (!selectedWeekRange.split(' ')[1]=='')){
                                                    
                                                    ftVal.push(selectedWeekRange.split(' ')[0]);
                                                }
                                                
                                                if(!($A.util.isUndefinedOrNull(weekRange[p+1]))){
                                                    
                                                    var nxt1week = weekRange[p+1].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt1week[1])) && (!nxt1week[1]=='')){
                                                        
                                                        ftVal.push(nxt1week[0]);
                                                    }
                                                }else{
                                                    
                                                    var nxt1week = nextYearWeekRange[0].split(' ');
                                                    var nxt2week = nextYearWeekRange[1].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt1week[1])) && (!nxt1week[1]=='')){
                                                        
                                                        ftVal.push(nxt1week[0]);
                                                    }
                                                    if(!($A.util.isUndefinedOrNull(nxt2week[1])) && (!nxt2week[1]=='')){
                                                        
                                                        ftVal.push(nxt2week[0]);
                                                    }
                                                }
                                                
                                                if(!($A.util.isUndefinedOrNull(weekRange[p+1])) && !($A.util.isUndefinedOrNull(weekRange[p+2]))){
                                                    var nxt2week = weekRange[p+2].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt2week[1])) && (!nxt2week[1]=='')){
                                                        
                                                        ftVal.push(nxt2week[0]);
                                                    }
                                                }else if(!($A.util.isUndefinedOrNull(weekRange[p+1])) && $A.util.isUndefinedOrNull(weekRange[p+2])){
                                                    var nxt2week = nextYearWeekRange[0].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt2week[1])) && (!nxt2week[1]=='')){
                                                        
                                                        ftVal.push(nxt2week[0]);
                                                    }
                                                }
                                                
                                            }
                                        } 
                                        
                                    }else{
                                        for(var p=0;p < monthlst.length;p++){
                                            if(monthlst[p] == selectedWeekRange)
                                            {
                                                if(!($A.util.isUndefinedOrNull(selectedWeekRange.split(' ')[1])) && (!selectedWeekRange.split(' ')[1]=='')){
                                                    
                                                    ftVal.push(selectedWeekRange.split(' ')[0]);
                                                }
                                                
                                                if(!($A.util.isUndefinedOrNull(monthlst[p+1]))){
                                                    
                                                    var nxt1week = monthlst[p+1].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt1week[1])) && (!nxt1week[1]=='')){
                                                        
                                                        ftVal.push(nxt1week[0]);
                                                    }
                                                }else{
                                                    
                                                    var nxt1week = nextYearWeekRange[0].split(' ');
                                                    var nxt2week = nextYearWeekRange[1].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt1week[1])) && (!nxt1week[1]=='')){
                                                        
                                                        ftVal.push(nxt1week[0]);
                                                    }
                                                    if(!($A.util.isUndefinedOrNull(nxt2week[1])) && (!nxt2week[1]=='')){
                                                        
                                                        ftVal.push(nxt2week[0]);
                                                    }
                                                }
                                                
                                                if(!($A.util.isUndefinedOrNull(monthlst[p+1])) && !($A.util.isUndefinedOrNull(monthlst[p+2]))){
                                                    var nxt2week = monthlst[p+2].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt2week[1])) && (!nxt2week[1]=='')){
                                                        
                                                        ftVal.push(nxt2week[0]);
                                                    }
                                                }else if(!($A.util.isUndefinedOrNull(monthlst[p+1])) && $A.util.isUndefinedOrNull(monthlst[p+2])){
                                                    var nxt2week = nextYearWeekRange[0].split(' ');
                                                    if(!($A.util.isUndefinedOrNull(nxt2week[1])) && (!nxt2week[1]=='')){
                                                        
                                                        ftVal.push(nxt2week[0]);
                                                    }
                                                }
                                                
                                            }
                                        } 
                                    }
                                }    
                                
                                //END :
                                
                                if( parseInt(yearValue) > (new Date().getFullYear())){
                                    
                                    var weekRange = component.get('v.currentYearWeeks');
                                    
                                    for( var i=0;i<weekRange.length;i++){
                                        var mon = weekRange[i].split(' ');
                                        if(mon[0] == selectedWeekRange.split(' ')[0]){
                                            currentMonth = mon[0];
                                            if(weekRange[i+1]!=null) 
                                            {
                                                var nxtsp = weekRange[i+1].split(' ');
                                                nxtMonth1 = nxtsp[0];
                                            }
                                            else
                                            {
                                                var nxtsp = nextYearWeekRange[0].split(' ');
                                                var nxtsp1 = nextYearWeekRange[1].split(' ');
                                                nxtMonth1 = nxtsp[0] ;
                                                nxtMonth2 = nxtsp1[0];
                                            }
                                            if(weekRange[i+2] != null && weekRange[i+1] !=null){
                                                var nxt2sp = weekRange[i+2].split(' ');
                                                nxtMonth2 = nxt2sp[0] 
                                            }
                                            else if(weekRange[i+1] !=null && ($A.util.isUndefinedOrNull(weekRange[i+2]))){
                                                var nxt2sp = nextYearWeekRange[0].split(' ');
                                                nxtMonth2 = nxt2sp[0]; 
                                            }
                                        }
                                    }            
                                    
                                }else{
                                    
                                    for( var i=0;i<lstMonths.length;i++){
                                        var mon = lstMonths[i].split(' ');
                                        if(mon[0] == selectedWeekRange.split(' ')[0]){
                                            currentMonth = mon[0];
                                            if(lstMonths[i+1]!=null) 
                                            {
                                                var nxtsp = lstMonths[i+1].split(' ');
                                                nxtMonth1 = nxtsp[0];
                                            }
                                            else
                                            {
                                                var nxtsp = nextYearWeekRange[0].split(' ');
                                                var nxtsp1 = nextYearWeekRange[1].split(' ');
                                                nxtMonth1 = nxtsp[0] ;
                                                nxtMonth2 = nxtsp1[0];
                                            }
                                            if(lstMonths[i+2] != null && lstMonths[i+1] !=null){
                                                var nxt2sp = lstMonths[i+2].split(' ');
                                                nxtMonth2 = nxt2sp[0] 
                                            }
                                            else if(lstMonths[i+1] !=null && ($A.util.isUndefinedOrNull(lstMonths[i+2]))){
                                                var nxt2sp = nextYearWeekRange[0].split(' ');
                                                nxtMonth2 = nxt2sp[0]; 
                                            }
                                        }
                                    }
                                }
                                //debugger;
                                for(var key =0;key<ftVal.length;key++){
                                    
                                    if(currentMonth==ftVal[key]){
                                        isCurrentMonthVal =true;
                                    }else if(nxtMonth1 == ftVal[key]){
                                        isNxtMonthVal1 =true;
                                    }else if(nxtMonth2 == ftVal[key]){
                                        isNxtMonthVal2 =true; 
                                    }
                                    
                                    
                                }
                                for(var k =0;k<lstWrap.length;k++){
                                    
                                    if((!isCurrentMonthVal)&& isNxtMonthVal1 && isNxtMonthVal2 && monthValue[0] == currentMonth && lstWrap[k].objAccount!=null && lstWrap[k].objProduct!=null && lstWrap[k].objcontact!=null
                                       && lstWrap[k].ProdYear!=null && lstWrap[k].EvalYear != null && lstWrap[k].CommYear!=null && lstWrap[k].ProdWeek!=null
                                       && lstWrap[k].EvalWeek!=null && lstWrap[k].CommWeek!=null){
                                        
                                        isCurrentMonthVal = true;
                                    }
                                    else if((!isNxtMonthVal1)&& isCurrentMonthVal && isNxtMonthVal2 && monthValue[0] == nxtMonth1 && lstWrap[k].objAccount!=null && lstWrap[k].objProduct!=null && lstWrap[k].objcontact!=null
                                            && lstWrap[k].ProdYear!=null && lstWrap[k].EvalYear != null && lstWrap[k].CommYear!=null && lstWrap[k].ProdWeek!=null
                                            && lstWrap[k].EvalWeek!=null && lstWrap[k].CommWeek!=null) {
                                        
                                        isNxtMonthVal1 = true;
                                    }
                                        else if((!isNxtMonthVal2)&& isCurrentMonthVal && isNxtMonthVal1 && monthValue[0] == nxtMonth2 && lstWrap[k].objAccount!=null && lstWrap[k].objProduct!=null && lstWrap[k].objcontact!=null
                                                && lstWrap[k].ProdYear!=null && lstWrap[k].EvalYear != null && lstWrap[k].CommYear!=null && lstWrap[k].ProdWeek!=null
                                                && lstWrap[k].EvalWeek!=null && lstWrap[k].CommWeek!=null) {
                                            
                                            isNxtMonthVal2 = true;
                                        }
                                }
                                
                                
                                if(isNxtMonthVal2 && isNxtMonthVal1 && isCurrentMonthVal){
                                    validEntery =true;
                                }else{
                                    validEntery =false;
                                }
                                
                                
                                
                                
                                if(validEntery){
                                    component.set("v.isSubmit", true);
                                }else{
                                    
                                    if(isCurrentMonthVal == false /*&& parseInt(yearValue) == new Date().getFullYear()*/){
                                        var showToast = $A.get("e.force:showToast");
                                        showToast.setParams({
                                            "type": "error",
                                            "message": $A.get("$Label.c.Planning_required_for_week_Range") +currentMonth
                                        });
                                        showToast.fire(); 
                                    }else if(isNxtMonthVal1 == false ){
                                        
                                        var showToast = $A.get("e.force:showToast");
                                        showToast.setParams({
                                            "type": "error",
                                            "message": $A.get("$Label.c.Planning_required_for_week_Range") +nxtMonth1
                                        });
                                        showToast.fire(); 
                                    }else if(isNxtMonthVal2 == false ){
                                        
                                        var showToast = $A.get("e.force:showToast");
                                        showToast.setParams({
                                            "type": "error",
                                            "message": $A.get("$Label.c.Planning_required_for_week_Range") +nxtMonth2
                                        });
                                        showToast.fire(); 
                                    }
                                }
                                
                            }//Validentery end 
                            
                        }else{
                            component.set('v.isShowSpinner',false);
                            validEntery =false;
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
            
            
        }else{
            
            var showToast = $A.get("e.force:showToast");
            showToast.setParams({
                "type": "error",
                "message": $A.get("$Label.c.No_Records_to_submit")
            });
            showToast.fire(); 
        }
        
    },
    openRejectModal :function(component, event, helper) {
        
         component.set("v.isReject", true);
    },
    closeModel: function(component, event, helper) {
        component.set("v.isModalOpen", false);
        component.set("v.isSubmit", false);
        component.set('v.reasonForDelete',null);
        component.set('v.isIdAvailable',false);
        component.set("v.isRequestToSubmit", false);
        component.set("v.isReject", false);
    },
    go:function(component, event, helper) {
        // alert()
        helper.getRecords(component, event, helper);
        
    },
    goToReport:function(component,event,helper){
        var action = component.get('c.reportName');
        console.log('Action',action);
        action.setCallback(this,function(response){
            console.log('error',response.getError());
            if(response.getState()==='SUCCESS'){
                console.log('In success');
                
               debugger; 
              //  window.location.href = "/lightning/r/Report/"+response.getReturnValue()+"/view";  
              //  window.location.href = "/turkeyemployee/s/report/"+response.getReturnValue()+"/BD-Tracker-With-Sales-Person";
               console.log('Retunr value', response.getReturnValue());
               window.location.href = response.getReturnValue();
            } 
        });
        $A.enqueueAction(action);
    },
    validateMonth : function(component, event, helper){
        helper.ValidateMonthVal(component, event, helper);
        helper.updateRequestToSubmit(component,event,helper);
        helper.RSMApprovalforSubmit(component,event,helper);
    },
    checkSelectedWeek:function(component, event, helper){
        helper.validateSelectedWeek(component, event, helper); 
        helper.defaultWeeks(component, event, helper); 
        helper.getRecords(component,event,helper);
        
        helper.updateRequestToSubmit(component,event,helper);
        helper.RSMApprovalforSubmit(component,event,helper);
        
    },
    
    permitSubmission : function(component,event,helper){
        
    },
    requestForSubmit: function(component,event,helper){
		
        helper.makeReSubmitRequest(component,event,helper);
        
    },
    
    approveRequest:function(component,event,helper){
        var action = component.get('c.approvePlan');
        var range = component.get('v.selectedMonth').split(' ')[0];
        action.setParams({
            "uID":component.get("v.userId"),
            "Month":range,
            "selYear" :component.get('v.selectedYear')
        });
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
              component.set('v.approveReject',true)
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    
                    "type": "success",
                    "message": $A.get("$Label.c.Request_has_been_approved")
                });
                showToast.fire(); 
            } 
        });
        $A.enqueueAction(action);
    },
    RejectRequest:function(component,event,helper){
        var action = component.get('c.rejectPlan');
        var range = component.get('v.selectedMonth').split(' ')[0];
        action.setParams({
            "uID":component.get("v.userId"),
            "comment":component.get('v.rejectComment'),
            "Month":range,
            "selYear" :component.get('v.selectedYear')
                         });
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
              component.set('v.isReject',false);
              component.set('v.approveReject',true)
                var showToast = $A.get("e.force:showToast");
                showToast.setParams({
                    "type": "Success",
                    "message": $A.get("$Label.c.Request_has_been_rejected")
                });
                showToast.fire(); 
            } 
        });
        $A.enqueueAction(action);
    },
    
})