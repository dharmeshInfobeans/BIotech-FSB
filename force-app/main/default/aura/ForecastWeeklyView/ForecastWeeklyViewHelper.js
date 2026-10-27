({	/*** Designed to be called by the renderer during infinite scrolling events.
     * Increments the page number then fires page change event.*/
    
    getNextPage : function( component ) {
        var hasMoreRecord = component.get( 'v.hasMoreProductRecord' );
        console.log('***hasMoreRecord***'+hasMoreRecord);
        if(hasMoreRecord) {
            var pageNumber = component.get( 'v.pageNumber' );
            var pageSize = component.get( 'v.pageSize' );
            
            pageNumber++;
            
            component.set( 'v.pageNumber', pageNumber );
            component.set( 'v.pageSize', pageSize );
            //component.set( 'v.isShowMoreRecordSpinner', true );
            this.firePageChangeEvent( component );
        }
    },
    /*** Notify that there's a request for specific page of data.
     * It is the responsibility of the developer to listen for the page change event 
     *and update the table's rows accordingly.*/
    
    firePageChangeEvent : function( component) {       
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        var userId = $A.get("$SObjectType.CurrentUser.Id");
        var selectedBranchCode = component.get("v.selectedBranchCode");
        var selectedBranchName = component.get("v.selectedBranchName");
        var selectedRegionCode = component.get("v.selectedRegionCode");
        var selectedMonth = component.get("v.selectedMonthNumber");
        var selectedYear = component.get("v.selectedMonthYear");
		
        
        if(pageNumber == 1){
            component.set("v.isShowSpinnerChild", true);
        }
        else{ 
            this.hideMoreRecordSpinner(component);
        }
        console.log('*pageNumber***'+pageNumber);//0
        
        var wholeWrapper = component.get("v.weeklyForecastObj");
        console.log("************v.wholeWrapper",wholeWrapper);
        
        var action = component.get("c.getWeeklyForecastDetails");
        action.setParams({'currentUserId' : userId,
                          'selectedYear' : selectedYear,
                          'selectedRegionCode' : selectedRegionCode,
                          'selectedBranchName' : selectedBranchName,
                          'selectedBranchCode' : selectedBranchCode,
                          'selectedMonth' : selectedMonth,
                          'page':pageNumber, 
                          'pageSize':pageSize});
        
        action.setCallback(this,function(data){
            var state = data.getState();
            if (state == "SUCCESS") {
            console.log("Page %d loaded in %fms", 
                        pageNumber,
                        performance.now() - startTime);
            var retResponse = data.getReturnValue();
            console.log("************retResponse",retResponse);
            var hasMoreRecord = false;
            
            if(retResponse.weeklyProductObj.length == 0){                
                hasMoreRecord = false;
                component.set('v.hasMoreProductRecord', hasMoreRecord); 
                if(pageNumber > 1){ 
                    component.set('v.msgPbeList','No more items to display.');
                } else {
                    component.set("v.weeklyForecastObj",retResponse);
                    component.set('v.msgPbeList','No items to display.');
                }
                
            } else {
                console.log('**************');
                console.log(wholeWrapper);
                console.log('pageNumber',pageNumber);
                
                if(pageNumber > 1) {
                    for(var i =0; i < retResponse.weeklyProductObj.length ; i++){
                        wholeWrapper.weeklyProductObj.push(retResponse.weeklyProductObj[i]);
                    }
                    wholeWrapper.weeklyProductObj.sort(function (x, y) {
                        return x.intDiv - y.intDiv;
                    });
                    component.set("v.weeklyForecastObj",wholeWrapper);
					
                } else {
                    component.set("v.weeklyForecastObj",retResponse);
                     component.set("v.isShowSpinnerChild", false); //added by pk on 6 12
                    console.log('wholeWrapper in else',component.get("v.weeklyForecastObj"));
                }
                
                hasMoreRecord = true;
                component.set('v.hasMoreProductRecord', hasMoreRecord);
                component.set('v.msgPbeList','Loading...');
                //component.set('v.isShowMoreRecordSpinner',true);   //added by pk             
            }
            
            /*if(pageNumber == 1){
                component.set("v.isShowSpinnerChild", false);
                 console.log('inside if spinner');
            }
            else{ 
                this.hideMoreRecordSpinner(component);
                 console.log('inside in else spinner');
            }*/
        } 
        }); 
        var startTime = performance.now();
        
        $A.enqueueAction(action);
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
         //component.set("v.isShowSpinnerChild", true); //added by pk on 6 12
    },

})