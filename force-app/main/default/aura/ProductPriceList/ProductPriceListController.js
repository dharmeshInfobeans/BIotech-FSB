({
    /* Initialization & Get List Of Subordinates */  
    doInit : function(component, event, helper) {
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        console.log("pageSize:-->"+pageSize);
        component.set('v.isSelectDefaultProducts', true);
        helper.firePageChangeEvent( component, pageNumber, pageSize );
    },
    
    //Sorting logic
    sortColumnList : function(component,event,helper){
        var sortColumnName = event.currentTarget.dataset.value;
        
        var existingSortSelectedTab = component.get("v.selectedSortColumn");
        //var existingSortOrder = component.get("v.isAsc");
        var existingSortOrder = component.get("v.sortOrder");
        
        component.set("v.selectedSortColumn", sortColumnName);
        
        console.log(existingSortSelectedTab);
        console.log(existingSortOrder);
        
        if(existingSortSelectedTab != sortColumnName) {
            //component.set("v.isAsc", 'true');   
            component.set("v.sortOrder", 'asc');    
        } else {
            if(existingSortOrder=='asc'){
                //component.set("v.isAsc", 'false');   
                component.set("v.sortOrder", 'desc');    
            } else {
                //component.set("v.isAsc", 'true');  
                component.set("v.sortOrder", 'asc');    
            }
        }
        
        helper.resetPageNumber(component)
        helper.firePageChangeEvent(component);
    },
    
    
    selectProduct : function(component, event, helper) {
        var selectedRec = event.getParam("selectedPbe");
        
        console.log('selectedRec'+selectedRec);
        
        helper.addToSelectedProductList(component, selectedRec);
        
    },
    
    removeSelectedItem : function(component, event, helper) {
        var removedPbe = event.getParam("selectedPbe");
        console.log(removedPbe);
        helper.removeSelected(component,removedPbe);
    },
    
    resetPbeList : function(component, event, helper){
        helper.resetPriceList(component);
    },
    
    /* Initialization & Get List Of Subordinates */  
    searchProductItems : function(component, event, helper) {
        
        helper.resetPageNumber(component)
        helper.firePageChangeEvent(component);
        
    },
    

    
    addSelectedProductsToQli : function(component, event, helper){
        var selectedProductList = component.get("v.selectedProducts");
        var selectItemEvent = component.getEvent("addProductToQliEvent");
        selectItemEvent.setParams({"selectedPbeList": selectedProductList});
        selectItemEvent.fire();
        var chkBoxId;
        for(var i=0; i< selectedProductList.length; i++){
            //Remove all the checked Items
            chkBoxId = 'chk_'+selectedProductList[i].Id;
            document.getElementById(chkBoxId).checked = false;
        }
        //Remove selected products
        component.set("v.selectedProducts", []);
        component.set("v.selectedProductCnt", 0);
        
        var pbeList = component.get("v.pricebookEntries");
        console.log('selectedProductList' +selectedProductList.length);
        console.log('pbeList '+pbeList.length);
        for(var i=0; i<pbeList.length;i++){
            for(var j=0; j< selectedProductList.length; j++){
                console.log('BG >>> pbeList[i] : '+pbeList[i].Name);
                console.log('BG >>> pbeList[i].Product__r.Dummy_Product_Code__c : '+pbeList[i].Is_Backup__c);
                console.log('BG >>> selectedProductList[j].Product__r.Dummy_Product_Code__c : '+selectedProductList[j].Is_Backup__c);
                console.log('pbeList[i].IsHide : '+pbeList[i].IsHide);
                if(pbeList[i].Product__r.Dummy_Product_Code__c == selectedProductList[j].Product__r.Dummy_Product_Code__c && pbeList[i].Is_Backup__c == selectedProductList[j].Is_Backup__c ){
                    pbeList[i].IsHide = true;
                    console.log('hide');
                    break;
                } 
				
            }
        }
        component.set("v.pricebookEntries", pbeList);
    },
    
    calculateWidth : function(component, event, helper) {
        var childObj = event.target
        var parObj = childObj.parentNode;
        var count = 1;
        //parent element traversing to get the TH
        while(parObj.tagName != 'TH') {
            parObj = parObj.parentNode;
            count++;
        }
        console.log('final tag Name'+parObj.tagName);
        //to get the position from the left for storing the position from where user started to drag
        var mouseStart=event.clientX; 
        component.set("v.mouseStart",mouseStart);
        component.set("v.oldWidth",parObj.offsetWidth);
        helper.resizeColumn(component,event);
    },
    
    setNewWidth : function(component, event, helper) {
        helper.resizeColumn(component,event);
    },
    
    setNewWidth1 : function(component, event, helper) {
        var childObj = event.target
        var parObj = childObj.parentNode;
        var count = 1;
        //parent element traversing to get the TH
        while(parObj.tagName != 'TH') {
            parObj = parObj.parentNode;
            count++;
        }
        
        var columnVal = childObj.dataset.value;
        if(columnVal !== undefined) {
            console.log('***columnVal'+columnVal);
            
            //To calculate the new width of the column
            var newWidth = event.clientX;
            console.log('**event.clientX**' + event.clientX)
            
            //if(event.clientX > minWidth &&  event.clientX < maxWidth )
            //var newWidth = event.clientX;
            if(event.clientX > 50)
                parObj.style.width = newWidth+'px';//assign new width to column
        }
    },
    
    
    startColumnDrag : function(component, event, helper) {
        var childObj = event.target
        var parObj = childObj.parentNode;
        var count = 1;
        //parent element traversing to get the TH
        while(parObj.tagName != 'TH') {
            parObj = parObj.parentNode;
            count++;
        }
        console.log('final tag Name'+parObj.tagName);
        //to get the position from the left for storing the position from where user started to drag
        var mouseStart=event.clientX; 
        console.log('***mouseStart****'+mouseStart);
        console.log('***parObj.offsetWidth****'+parObj.offsetWidth);
        component.set("v.mouseStart",mouseStart);
        component.set("v.oldWidth",parObj.offsetWidth);
    },
    
    start : function(component, event, helper) {
        var childObj = event.target
        var parObj = childObj.parentNode;
        var count = 1;
        //parent element traversing to get the TH
        while(parObj.tagName != 'TH') {
            parObj = parObj.parentNode;
            count++;
        }
        
        //to get the position from the left for storing the position from where user started to drag
        var mouseStart=event.clientX; 
        console.log('***Start mouseStart****'+mouseStart);
        console.log('***Start parObj.offsetWidth****'+parObj.offsetWidth);
        
    },
    
    end : function(component, event, helper){
        var childObj = event.target
        var parObj = childObj.parentNode;
        var count = 1;
        //parent element traversing to get the TH
        while(parObj.tagName != 'TH') {
            parObj = parObj.parentNode;
            count++;
        }
        
        //to get the position from the left for storing the position from where user started to drag
        var mouseStart=event.clientX; 
        console.log('***Stop mouseStart****'+mouseStart);
        console.log('***Stop parObj.offsetWidth****'+parObj.offsetWidth);
    }
    
})