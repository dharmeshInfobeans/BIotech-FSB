({
    /*** Designed to be called by the renderer during infinite scrolling events.
     * Increments the page number then fires page change event.*/
    
    getNextPage : function( component ) {
        var hasMoreRecord = component.get( 'v.hasMoreProductRecord' );
        if(hasMoreRecord) {
            var pageNumber = component.get( 'v.pageNumber' );
            var pageSize = component.get( 'v.pageSize' );
            
            pageNumber++;
            
            component.set( 'v.pageNumber', pageNumber );
            component.set( 'v.pageSize', pageSize );
            
            this.firePageChangeEvent( component );
        }
    },
    /*** Notify that there's a request for specific page of data.
     * It is the responsibility of the developer to listen for the page change event 
     *and update the table's rows accordingly.*/
    
    firePageChangeEvent : function( component) {       
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        console.log('ooo',pageSize);
        //var userId = $A.get("$SObjectType.CurrentUser.Id");
        var selectedCustomerCode = component.get("v.selectedCustomerCode");
        //var selectedRegionCode = component.get("v.selectedRegionCode");
        var fromselectedMonth = component.get("v.fromselectedMonth");
        var fromselectedYear = component.get("v.fromselectedYear");
        var toselectedMonth = component.get("v.toselectedMonth");
        var toselectedYear = component.get("v.toselectedYear");
        console.log('selected year**',fromselectedMonth);  
        console.log('selected month**',fromselectedYear);  
        console.log('selected year**',toselectedMonth);  
        console.log('selected month**',toselectedYear);  
        var numberOfMonths=(toselectedYear-fromselectedYear)*12+(toselectedMonth-fromselectedMonth)+1;
        console.log('BG >>> ',numberOfMonths);
        if(numberOfMonths > 6) {
            var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        type: "error",
                        title: "Error",
                        message: "The date range must not be more than 6 months",
                        mode:"sticky"
                    });
                    toastEvent.fire();
                    component.set("v.isShowSpinnerChild", false);
                    component.set("v.weeklyForecastObj",'');
        }
        else if(numberOfMonths < 0) {
            var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        type: "error",
                        title: "Error",
                        message: "The selected date range must be valid",
                        mode:"sticky"
                    });
                    toastEvent.fire();
                    component.set("v.isShowSpinnerChild", false);
                    component.set("v.weeklyForecastObj",'');
        }
        else {
            if(pageNumber == 1){
                component.set("v.isShowSpinnerChild", true);
            }
            else{ 
                this.hideMoreRecordSpinner(component);
            }
            
            var wholeWrapper = component.get("v.weeklyForecastObj");
            console.log('selectedCustomerCode : ',selectedCustomerCode);
            var action = component.get("c.getWeeklyForecastDetails");
            action.setParams({'fromselectedYear' : fromselectedYear,
                            /*'selectedRegionCode' : selectedRegionCode,*/
                            'selectedCustomerCode' : selectedCustomerCode,
                            'fromselectedMonth' : fromselectedMonth,
                            'page':pageNumber, 
                            'pageSize':pageSize,
                            'toselectedYear' : toselectedYear,
                            'toselectedMonth' : toselectedMonth});
            
            action.setCallback(this,function(data){
                var state = data.getState();
                if (state == "SUCCESS") {
                    console.log("Page %d loaded in %fms", 
                                pageNumber,
                                performance.now() - startTime);
                    var retResponse = data.getReturnValue();
                    console.log("************retResponse",retResponse);
                    var hasMoreRecord = false;
                    var totalAPOnAccount = retResponse.totalProducts;
                    var aplistsize = retResponse.weeklyProductObj.length;
                    console.log('product length**',retResponse.weeklyProductObj.length);
                    if(retResponse.weeklyProductObj.length == 0){                
                        hasMoreRecord = false;
                        component.set('v.hasMoreProductRecord', hasMoreRecord); 
                        if(pageNumber > 1){ 
                            component.set('v.msgList',$A.get('$Label.c.No_more_items_to_display'));
                            component.set("v.hasMoreProductRecord", false);//added on 4/3
                            component.set("v.isShowSpinnerChild", false);//added on 4/3
                        } else {
                            component.set('v.',$A.get('$Label.c.No_items_to_display'));
                            component.set("v.isShowSpinnerChild", false);//added on 28/2
                            component.set("v.weeklyForecastObj",'');//added on 28/2
                            component.set("v.hasMoreProductRecord", false);//added on 4/3
                        }
                        
                    } else {	               
                        if(pageNumber > 1) {
                            for(var i =0; i < retResponse.weeklyProductObj.length ; i++){
                                wholeWrapper.weeklyProductObj.push(retResponse.weeklyProductObj[i]);
                            }
                            wholeWrapper.weeklyProductObj.sort(function (x, y){
                                return x.intDiv - y.intDiv;
                            });
                            component.set("v.weeklyForecastObj",wholeWrapper);
                            //component.set('v.hasMoreProductRecord', true);//added on 4/3//commented on 31/3
                            //component.set('v.msgList','Loading...');////added on 4/3//commented on 31/3

                            if(retResponse.weeklyProductObj.length < 10){
                                component.set('v.hasMoreProductRecord', false);
                                component.set('v.msgList',$A.get('$Label.c.No_items_to_display'));
                            }
                            else{
                                component.set('v.hasMoreProductRecord', true);
                                
                                component.set('v.msgList',$A.get('Loading...'));
console.log('v.msgList:', component.get('v.msgList'));

                            }
                        }
                        else{
                            component.set("v.weeklyForecastObj",retResponse);
                            component.set("v.isShowSpinnerChild", false);
                            component.set('v.hasMoreProductRecord', true);
                            component.set('v.msgList',$A.get('$Label.c.No_more_items_to_display'));

                            console.log('product length',retResponse.weeklyProductObj.length);
                                                        console.log('retResponse.weeklyProductObj',retResponse.weeklyProductObj);

                            
                        }
                        /*component.set('v.hasMoreProductRecord', true);
                        component.set('v.msgList','Loading...');//commented on 19/2 
                        console.log('msggg',component.get('v.msgList'));*/
                    }
                } /*handle error scenario if exception comes in apex, turn of the spinner*/
                else if (state == "ERROR") {
                    component.set("v.isShowSpinnerChild", false);
                    component.set("v.weeklyForecastObj",'');
                }
            }); 
            var startTime = performance.now();
            
            $A.enqueueAction(action);
        }
    },
    toggleFullPageSpinner: function (cmp, event) {        
        var spinner = cmp.find("isShowSpinnerChild");
        $A.util.toggleClass(spinner, "slds-hide");
    },
    showMoreRecordSpinner : function( component ) {
        component.set("v.isShowMoreRecordSpinner", true); 
    },
    hideMoreRecordSpinner : function( component ) {
        component.set("v.isShowMoreRecordSpinner", false); 
    },
})