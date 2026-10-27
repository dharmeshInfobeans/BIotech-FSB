({
    /**
     * Designed to be called by the renderer during infinite scrolling events.
     * Increments the page number then fires page change event.
     */
    getNextPage : function( component ) {
        var hasMoreRecord = component.get( 'v.hasMorePbeRecord' );
        console.log('***hasMoreRecord***'+hasMoreRecord);
        if(hasMoreRecord) {
            var pageNumber = component.get( 'v.pageNumber' );
            var pageSize = component.get( 'v.pageSize' );
            
            pageNumber++;
            
            component.set( 'v.pageNumber', pageNumber );
            component.set( 'v.pageSize', pageSize );
            
            this.firePageChangeEvent( component );
        }
    },
    
    /**
     * Notify that there's a request for specific page of data.
     *
     * It is the responsibility of the developer to listen for the
     * page change event and update the table's rows accordingly.
     */
    
    firePageChangeEvent : function( component) {
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        var searchCmp = component.find("searchProduct");
        var searchStr = searchCmp.get("v.value");
        
        if(pageNumber == 1)
            this.toggleFullPageSpinner(component);
        else
            //this.toggleMoreRecordSpinner(component);
            this.showMoreRecordSpinner(component);
        
        console.log('*pageNumber***'+pageNumber);
        var action = component.get("c.getPricebookEntries");
        var orderId = component.get("v.recordId");//This is the order Id
        /*
        action.setParams({"page":pageNumber,
                          "pageSize":pageSize,
                          "accountId":accountRecordId,
                          "searchStr":searchStr});
                          */
        //  action.setParams({"page":pageNumber, "pageSize":pageSize});
        var sortColumn =  component.get("v.selectedSortColumn");
        var sortOrder =  component.get("v.sortOrder");
        
        action.setParams({"page":pageNumber, "pageSize":pageSize, 
                          'sortOrder': sortOrder , 'sortColumn': sortColumn,
                          'searchStr' : searchStr,"orderId":orderId });
        
        var pbeList = [];
        
        pbeList = component.get("v.pricebookEntries");
        
        action.setCallback(this,function(data){
            console.log("Page %d loaded in %fms", 
                        pageNumber,
                        performance.now() - startTime);
            var retResponse = data.getReturnValue();
            console.log('Data : ',retResponse);
            var hasMoreRecord = false;
            if(retResponse==null || retResponse.length == 0){
                hasMoreRecord = false;
                component.set('v.hasMorePbeRecord', hasMoreRecord);
                if(pageNumber > 1 && pbeList.length > 0) { 
                    component.set('v.msgPbeList',$A.get("$Label.c.No_more_items_to_display"));
                } else {
                    component.set("v.pricebookEntries",retResponse);
                    component.set('v.msgPbeList',$A.get("$Label.c.No_Active_Agreement_Available"));
                }
            } else {
                
                if(pbeList.length > 0 && pageNumber > 1) {
                    var allPbeItems = pbeList.concat(retResponse);
                    
                    component.set("v.pricebookEntries",allPbeItems);
                } else {
                    component.set("v.pricebookEntries",retResponse);
                }
                
                hasMoreRecord = true;
                
                component.set('v.hasMorePbeRecord', hasMoreRecord);
                
                if(component.get('v.isSelectDefaultProducts')){
                    //add products with less stock
                    this.selectDefaultProducts(component);
                }
            }
            
            if(pageNumber == 1)
                this.toggleFullPageSpinner(component);
            else 
                //this.toggleMoreRecordSpinner(component);
                this.hideMoreRecordSpinner(component);
            
        }); 
        var startTime = performance.now();
        
        $A.enqueueAction(action);
    },
    
    toggleFullPageSpinner: function (cmp, event) {
        //var childCmp = cmp.find("productListItemCmp");
        
        var spinner = cmp.find("productListSpinner");
        $A.util.toggleClass(spinner, "slds-hide");
    },
    
    toggleMoreRecordSpinner : function(cmp,event) {
        //var childCmp = cmp.find("productListItemCmp");
        var spinner = cmp.find("moreRecordSpinner");
        $A.util.toggleClass(spinner, "slds-hide");
    },
    
    showMoreRecordSpinner : function( component ) {
        component.set("v.spinner", true); 
    },
    
    hideMoreRecordSpinner : function( component ) {
        component.set("v.spinner", false); 
    },
    
    addToSelectedProductList : function(component, pbeRec){
        var selectedProductList = component.get("v.selectedProducts");
        var isExist = false;
        for(var i=0; i< selectedProductList.length; i++){
            if(selectedProductList[i].Id == pbeRec.Id){
                isExist = true;
            }
        }
        console.log('BG >>> 1 pbeRec : '+JSON.stringify(pbeRec));
        if(!isExist)
            selectedProductList.push(pbeRec);
        
        console.log('selectedProductList==>>',JSON.stringify(selectedProductList));
        component.set("v.selectedProducts", selectedProductList);
        component.set("v.selectedProductCnt", selectedProductList.length);
    },
    
    removeSelected : function(component, value){
        var selectedProductList = component.get("v.selectedProducts");
        var updatedProductList=[];
        console.log(value);
        
        for(var i=0; i< selectedProductList.length; i++ ) {
            if(selectedProductList[i].Id == value.Id){
                continue;
            } else {
                updatedProductList.push(selectedProductList[i]);
            }
        }
        component.set("v.selectedProducts", updatedProductList);
        component.set("v.selectedProductCnt", updatedProductList.length);
        
        //Remove selected chkbox
        var chkBoxId = 'chk_'+value.Id;
        if(document.getElementById(chkBoxId)!=null)
            document.getElementById(chkBoxId).checked = false;
        
    },
    
    /*
     *  Search product  
     */
    searchProduct : function(component, searchStr){
        console.log('searchStr**'+searchStr);
        var action = component.get("c.searchProducts");
        //action.setStorable();
        action.setParams({"searchStr":searchStr});
        action.setCallback(this,function(data){
            console.log("Page %s loaded in %fms", searchStr,
                        performance.now() - startTime);
            
            component.set("v.pricebookEntries",data.getReturnValue());

            console.log(data.getReturnValue());
            if(data.getReturnValue().length ==0){
                component.set('v.hasMorePbeRecord', true);
                component.set('v.msgPbeList',$A.get("$Label.c.No_item_found"));
            } else {
                component.set('v.hasMorePbeRecord', false);
            }
        }); 
        var startTime = performance.now();
        $A.enqueueAction(action);
    },
    
    /*
     * Reset page size and page number
     * 
     */
    resetPageNumber : function(component){
        var pageNumber = 1;
        component.set( 'v.pageNumber', pageNumber );
        component.set( 'v.hasMorePbeRecord', 'true' );
    },
    
    /*
     * 
     * 
     */
    resizeColumn : function(component,event) {
        var childObj = event.target
        var parObj = childObj.parentNode;
        var count = 1;
        //parent element traversing to get the TH
        while(parObj.tagName != 'TH') {
            parObj = parObj.parentNode;
            count++;
        }
        
        var columnVal = childObj.dataset.value;
        console.log(columnVal);
        if(columnVal !== undefined) {
            var rangeColumnWidthCmp = component.find("range_"+columnVal);
            console.log('**rangeColumnWidthCmp'+rangeColumnWidthCmp);
            
            var minWidth = rangeColumnWidthCmp.get("v.min");
            var maxWidth = rangeColumnWidthCmp.get("v.max");
            
            var mouseStart = component.get("v.mouseStart");
            var oldWidth = component.get("v.oldWidth");
            //To calculate the new width of the column
            var newWidth = event.clientX- parseFloat(mouseStart)+parseFloat(oldWidth);
            console.log('**event.clientX**' + event.clientX)
            //var newWidth = event.clientX;
            
            if(event.clientX > minWidth && event.clientX < maxWidth)
                parObj.style.width = newWidth+'px';//assign new width to column
        }
    },
    
    selectDefaultProducts : function(component){
        var pbeList = component.get("v.pricebookEntries");
        var selectedProductList=[];
        var isExist;
        if(pbeList.length > 0){
            for(var i=0;i<pbeList.length;i++){
                
                pbeList[i].checked = false;
                pbeList[i].IsHide = false;
                if(!$A.util.isUndefinedOrNull(pbeList[i].Dealer_Stock_Managements__r) 
                   && pbeList[i].Dealer_Stock_Managements__r[0].Difference__c < 0){
                    selectedProductList.push(pbeList[i]);
                }
            }
            component.set('v.productsWithLessStock', selectedProductList);
        }
    },
    
    resetPriceList : function(component){
        var pricebookEntries = component.get("v.pricebookEntries");
        var selectedOrderItems = component.get("v.selectedOrderItems");
        
        if (!$A.util.isUndefinedOrNull(pricebookEntries)) {
            for(var i=0; i <pricebookEntries.length; i++){
                pricebookEntries[i].checked = false;
                pricebookEntries[i].IsHide = false;
                console.log('BG >>> resetPriceList : ');
                for(var j=0; j <selectedOrderItems.length; j++){
                    console.log("Checking Pricebook Entry:", {
                        PricebookDummyCode: pricebookEntries[i]?.Product__r?.Dummy_Product_Code__c,
                        SelectedProductCode: selectedOrderItems[j]?.ProductCode,
                        PricebookIsBackup: pricebookEntries[i]?.Is_Backup__c,
                        SelectedIsBackup: selectedOrderItems[j]?.isBackup
                    });
                    //console.log('BG >>> selectedOrderItems[j] : '+JSON.stringify(selectedOrderItems[j]));
                    if(pricebookEntries[i].Product__r.Dummy_Product_Code__c == selectedOrderItems[j].ProductCode && pricebookEntries[i].Is_Backup__c == selectedOrderItems[j].isBackup){
                        pricebookEntries[i].IsHide = true;
                        console.log("Match found! Setting IsHide to true for:", pricebookEntries[i]);

                        break;
                    }
                }
            }
        }
        component.set("v.pricebookEntries",pricebookEntries);
    }
    
    

    
})