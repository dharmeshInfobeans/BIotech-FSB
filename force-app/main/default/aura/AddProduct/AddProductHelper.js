({
    getColumnDefinitions : function(component, event) {
        component.set('v.columns', [
            {label: 'Product Name', fieldName: 'Name', iconName:'utility:travel_and_places',type: 'text'},
            {label: 'Description', fieldName: 'Dummy_Product_Description__c', type: 'text'},
            {label: 'Dummy Code', fieldName: 'Dummy_Product_Code__c', type: 'text',initialWidth:130},
            {label: 'MSP', fieldName: 'MSP__c',type: 'currency',initialWidth:100, },
            {label: '', type: 'button',initialWidth:120, typeAttributes: { label: 'ADD', variant:'brand', iconName:'utility:add', name: 'add_product', title: 'Click To Add Product'}}
            
        ]);
        
    },
    showToast : function(params){
        var toastEvent = $A.get("e.force:showToast");
        if(toastEvent){
            console.log("IN ZZZ AddProdComp-->H-->In showToast_M-->If toast evt exist..")
            toastEvent.setParams(params);
            toastEvent.fire();
        } else{
            console.log("IN ZZZ AddProdComp-->H-->In showToast_M-->If toast evt doesn't exist..")
            alert(params.message);
        }
    },
    closeModalOrPopupWindow : function(){
        var closeModalOrPopUp = $A.get("e.force:closeQuickAction");
        closeModalOrPopUp.fire();
        
    },
    
    reloadDataTable : function(){
        var refreshEvent = $A.get("e.force:refreshView");
        if(refreshEvent){
            refreshEvent.fire();
        }
    },
    openModal: function(component, event) {
        //For Display Modal, Set the "openModal" attribute to "true"
        component.set("v.openModal", true);
        //component.set("v.oppProductId", oppProd);
    },
     
    closeModal: function(component, event) {
        //For Close Modal, Set the "openModal" attribute to "fasle"  
        component.set("v.openModal", false);
        component.set("v.oppProductId", ""); //Resetting oppProdId
    },
    
    showSpinner : function(component){
        component.set("v.showSpinner",true);
    },
    hideSpinner : function(component){
        component.set("v.showSpinner",false);
    },
    getExistingOppProds : function(component, event) {
        var action = component.get("c.getOpportunityProducts");
        action.setParams({
            "oppId": component.get('v.recordId')
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                var retDatas = response.getReturnValue();
                //this.hideSpinner(component);
                //console.log("FROM APEX-->Existing OppProds-->"+JSON.stringify(response.getReturnValue()));
                var prodIdsToBeRemoved = [];
                for (var i = 0; i < retDatas.length; i++){
                    var retData = retDatas[i];
                    if (retData.Product__r){
                        //retData.Sales_Price__c = retData.Product__r.MSP__c; //Initially setting selling price as prod's msp.
                        retData.ProductName = retData.Product__r.Name;    //Add new Property
                        retData.ProductMSP  = retData.Product__r.MSP__c;   //Add new Property
                    }
                    retData.Product__r = undefined; // NOW Removing Parent(Product) details from response after adding prod's Name and MSP
                    prodIdsToBeRemoved.push(retData.Product__c);
                }
                
                
                //console.log("FROM APEX-->Existing OppProds-->Modified retData-->"+JSON.stringify(retDatas));
                component.set("v.oppProducts",retDatas);
                component.set("v.prodIdToBeRemoved",prodIdsToBeRemoved);
                console.log("FROM APEX-->Existing OppProds-->Id To Remove-->"+JSON.stringify(component.get("v.prodIdToBeRemoved")));
                //console.log("FROM APEX-->Existing OppProds-->After AddingNewProp-->"+JSON.stringify(component.get("v.oppProducts")));
                
                
                this.removeProductFromProductList(component, event);
            }else{
                this.hideSpinner(component);
                console.log("ERROR in getting Events from Apex!!");
            }
        });
        $A.enqueueAction(action);
    },
    removeProductFromProductList : function(component, event) {
        //console.log("IN ZZZ AddProdComp-->H-->In removeProductFromProductList_M!!");
        
        var prodList = component.get("v.data");
        var prodIdsToRemove = component.get("v.prodIdToBeRemoved");
        //console.log("IN ZZZ AddProdComp-->H-->removeProductFromProductList_M-->ProdList-->"+JSON.stringify(prodList));
        //console.log("IN ZZZ AddProdComp-->H-->removeProductFromProductList_M-->prodIdsToRemove-->"+JSON.stringify(prodIdsToRemove));
        
        if(!$A.util.isEmpty(prodIdsToRemove) && !$A.util.isEmpty(prodList)){
            
            for(var i = 0; i < prodIdsToRemove.length; i++){
                for(var j = 0; j < prodList.length; j++){
                    //console.log('In removeProductFromPrdLst-->prodList['+j+'].Id -->'+prodList[j].Id);
                    //console.log('In removeProductFromPrdLst-->prodIdsToRemove['+i+'] -->'+prodIdsToRemove[i]);
                    if(!$A.util.isEmpty(prodList[j])){
                        if( prodList[j].Id == prodIdsToRemove[i] ){
                            //console.log('In removeProductFromPrdLst-->EQUALS!!');
                            //console.log('In removeProductFromPrdLst-->To Slice'+j+'-->'+JSON.stringify(prodList[j]));
                            
                            prodList.splice(j,1);
                        }        
                    }
                    
                }
            }
            component.set("v.data",prodList);    
        }else{
            console.log("IN ZZZ AddProdComp-->H-->removeProductFromProductList_M--> Nothing To Remove From Product List.");
        }
        
    },
    saveOppProducts : function(component, event) {
        var oppProductsToSave = component.get('v.oppProducts');
        for(var i = 0; i < oppProductsToSave.length; i++){
            oppProductsToSave[i].Opportunity__c = component.get("v.recordId"); // Set OppId
            oppProductsToSave[i].ProductName = undefined; // Removing Extra Property-->ProductName
            oppProductsToSave[i].ProductMSP  = undefined; // Removing Extra Property-->ProductName
        }
        console.log("ON SAVE FINAL OppPRODUCTS-->"+JSON.stringify(component.get('v.oppProducts')));
        var action = component.get("c.saveOpportunityProducts");
        action.setParams({
            "oppProds": component.get('v.oppProducts')
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                this.showToast({
                    "title": "Success!!",
                    "type": "success",
                    "message": "Record updated successfully."
                });
                console.log("Save Data To Apex--> Success!!");
                this.closeModalOrPopupWindow();
                location.reload();
                //var retDatas = response.getReturnValue();
                //this.hideSpinner(component);
                //console.log("FROM APEX-->RCVD EVENTS-->"+JSON.stringify(response.getReturnValue()));
                //component.set("v.data", retDatas);
            }else{
                this.hideSpinner(component);
                console.log("ERROR in saving data to Apex-->Message-->"+JSON.stringify(response.getError()));
                this.closeModalOrPopupWindow();
                this.showToast({
                    "title": "Oops! Error Occurred..",
                    "type": "error",
                    "message": "There was error in saving record."
                });
            }
        });
        $A.enqueueAction(action);
        
        
    },
    removeProductFromLstAndAdd : function(component, event,row) {
        console.log("ZZZ InAddProductComp-->H-->In removeProduct_M !!");
        var rows = component.get('v.data');
        var rowIndex = rows.indexOf(row);
        var addNewOppProdObj = {};
        console.log("ZZZ InAddProductComp-->H-->removeProduct_M-->ROW INDEX-->"+JSON.stringify(rowIndex));
        
        rows.splice(rowIndex, 1);
        component.set('v.data', rows); 
        
        /*var tempProdIdVsRowDataObj = {};
        tempProdIdVsRowDataObj.Id = row.Id;
        tempProdIdVsRowDataObj.RowData = row;
        var storeDeletedRow = component.get("v.tempProductList");
        storeDeletedRow.push(tempProdIdVsRowDataObj);*/
        
        addNewOppProdObj.Opportunity__c = ''; ///component.get("v.recordId");
        addNewOppProdObj.Product__c = row.Id;
        addNewOppProdObj.Quantity__c ='';
        //addNewOppProdObj.Sales_Price__c ='';
        addNewOppProdObj.Sales_Price__c =row.MSP__c;
        addNewOppProdObj.Description__c ='';
        addNewOppProdObj.List_Price__c='';
        addNewOppProdObj.ProductName=row.Name;
        addNewOppProdObj.ProductMSP=row.MSP__c;
        var addToOppProducts = component.get("v.oppProducts");
        addToOppProducts.push(addNewOppProdObj);
        component.set("v.oppProducts",addToOppProducts);
        console.log("ZZZ InAddProductComp-->H-->removeProduct_M-->Final oppPRODUCTS-->"+JSON.stringify(component.get("v.oppProducts")));
        
        var prodIdsToRemove = component.get("v.prodIdToBeRemoved");
        prodIdsToRemove.push(row.Id);
        component.set("v.prodIdToBeRemoved",prodIdsToRemove);
        console.log('ID to Be Removed Array-->'+JSON.stringify(component.get("v.prodIdToBeRemoved")));
    },
    getAllProducts : function(component, event){
        var action = component.get("c.getAllProductByRegion");
        action.setCallback(this,function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                //console.log("FROM APEX-->RCVD EVENTS-->"+JSON.stringify(response.getReturnValue()));
                var prodIdVsProdDetailMap = component.get("v.prodIdVsProdDataMap");
                let retDatas = response.getReturnValue();
                for (var i = 0; i < retDatas.length; i++) {
                    prodIdVsProdDetailMap[retDatas[i].Id] = retDatas[i]; //storing data in Map as ProdId Vs ProdData
                }
                /* for (var i = 0; i < retDatas.length; i++) {
                    var retData = retDatas[i];
                    if (retData.What){
                        retData.AccountName = retData.What.Name;    
                    }
                    
                    if (retData.Owner){
                        retData.OwnerName = retData.Owner.Name;    
                    }
                }*/
                // console.log("RetVal-->Added Parent Prop-->"+JSON.stringify(retDatas));
                component.set("v.data", retDatas);
                this.removeProductFromProductList(component, event);
                //console.log("MAP DATA-->"+JSON.stringify(component.get("v.prodIdVsProdDataMap")));
            }else{
                this.hideSpinner(component);
                console.log("ERROR in getting Events from Apex!!");
            }
        });
        $A.enqueueAction(action);
        
    },
    getProductBySearchString : function(component,event,searchString){
        //console.log('H-->ProdBySearch');
        var action = component.get("c.getProductBySearchTerm");
        action.setParams({
            "searchKey": searchString
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                let retDatas = response.getReturnValue();
                
                //console.log("FROM APEX-->Prod By Search-->"+JSON.stringify(response.getReturnValue()));
                var prodIdsToRemove = component.get("v.prodIdToBeRemoved");
                //console.log('In Prod SEARCH-->Ids To Remove-->'+JSON.stringify(prodIdsToRemove));
                if(!$A.util.isEmpty(retDatas) && !$A.util.isEmpty(prodIdsToRemove)){
                    
                    for(var j = 0; j < prodIdsToRemove.length; j++){
                        for(var i = 0; i < retDatas.length; i++){
                            if(!$A.util.isEmpty(retDatas[i])){
                                //console.log('1H-->prodIdsToRemove[j]-->'+prodIdsToRemove[j]);
                                //console.log('1H-->retDatas[i].Id-->'+retDatas[i].Id);
                                if( prodIdsToRemove[j] == retDatas[i].Id ){
                                    //console.log('Resp Includes Id Which is in existingIdArray--> prodId is-->'+retDatas[i].Id);
                                    //console.log('Resp Includes Id Which is in existingIdArray-->2BE SPLICED-->'+JSON.stringify(retDatas[i]));
                                    retDatas.splice(i,1);
                                }   
                            } 
                        }  
                    }
                    /*for(var i = 0; i < retDatas.length; i++){
                        if(!$A.util.isEmpty(retDatas[i].Id)){
                            if(prodIdsToRemove.includes(retDatas[i].Id)){
                                console.log('Resp Includes Id Which is in existingIdArray--> prodId is-->'+retDatas[i].Id);
                                retDatas.splice(i,1);
                            }
                        }
                    }*/
                    component.set("v.data", retDatas);
                }else{
                    console.log('In Prod SEARCH-->No Apex Response');
                }
                
            }else{
                this.hideSpinner(component);
                console.log("ERROR in getting Events from Apex!!");
            }
        });
        $A.enqueueAction(action);
    },
    deleteOppProduct : function(component,event){
       console.log("IN ZZZ AddProdComp-->H-->In deleteOppProduct_M!");
       var oppProdId = component.get("v.oppProductId");
       console.log("IN ZZZ AddProdComp-->H-->In deleteOppProduct_M-->OppProdId-->"+oppProdId);
       var prodId = component.get("v.productId");
       console.log("IN ZZZ AddProdComp-->H-->In deleteOppProduct_M-->ProdId-->"+prodId);
       this.removeAddedProductHelper(component,event,prodId);
       
       if(!$A.util.isEmpty(oppProdId)){
        var action = component.get("c.deleteOpportunityProducts");
        action.setParams({
            "oppProductId": oppProdId,
            "oppId": component.get("v.recordId")
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                this.closeModal(component,event);
                this.showToast({
                    "title": "Success!!",
                    "type": "success",
                    "message": "LineItem deleted successfully."
                });
                var retData = response.getReturnValue();
                if(retData == 'deleted'){
                    console.log('IN ZZZ AddProdComp-->H-->In deleteOppProduct_M-->RECORD DELETED Successfully');
                }else if(retData == null){
                    console.log('IN ZZZ AddProdComp-->H-->In deleteOppProduct_M-->Opportunity Product doesnot exist.');
                }
            }else{
                this.hideSpinner(component);
                console.log("IN ZZZ AddProdComp-->H-->deleteOppProduct_M-->APEX ERROR-->ERROR while opportunity product line item.");
                this.closeModalOrPopupWindow();
                this.showToast({
                    "title": "Oops,Error Occurred!",
                    "type": "error",
                    "message": "Error while deleting Opportunity Product Lineitem, Please check log or contact administrator."
                });
            }
        });
        $A.enqueueAction(action);    
        }else{
            console.log("IN ZZZ AddProdComp-->H-->In deleteOppProduct_M-->Need OppProdId To Delete");
        }
        
    },
    removeAddedProductHelper: function(component,event,prodId) {
    	      
            var oppProds = component.get("v.oppProducts");
            var prodList = component.get("v.data");
            var prodIdVsProductDataMap = component.get("v.prodIdVsProdDataMap");
            
            var addToProdObj = {};
            console.log("ZZZ InAddProductComp-->C-->Before Slicing oppPRODUCTS-->"+JSON.stringify(component.get("v.oppProducts")));
            for(var i = 0; i < oppProds.length; i++){
                if( oppProds[i].Product__c == prodId ){
                    //addToProdObj = oppProds[i];
                    oppProds.splice(i,1);
                }
            }
            console.log("ZZZ InAddProductComp-->C-->After Slicing oppPRODUCTS-->"+JSON.stringify(component.get("v.oppProducts")));
            component.set("v.oppProducts",oppProds);
            
            
            
            //addToProdObj.Quantity__c    = undefined;
            //addToProdObj.Sales_Price__c = undefined;
            //addToProdObj.Description__c = undefined;
            //addToProdObj.List_Price__c  = undefined;
            
            var prodIdsToRemove = component.get("v.prodIdToBeRemoved");
            for(var j = 0; j < prodIdsToRemove.length; j++){
                if( prodIdsToRemove[j] == prodId ){
                    prodIdsToRemove.splice(j,1);
                }
            }
            component.set("v.prodIdToBeRemoved",prodIdsToRemove);
            //console.log('ID to Be Removed Array-->'+JSON.stringify(component.get("v.prodIdToBeRemoved")));
            
            console.log('Prod To Be Added TO ProdList-->'+JSON.stringify(prodIdVsProductDataMap[prodId]));
            //Adding Deleted Prod To Product List
            prodList.push(prodIdVsProductDataMap[prodId]);
            component.set("v.data",prodList);
	},
    handleShowConfirmationModal: function(component, event) {
        var modalBody;
        $A.createComponent("c:ConfirmLineItemDeletion", {},
           function(content, status) {
               if (status === "SUCCESS") {
                   modalBody = content;
                   component.find('overlayLib').showCustomModal({
                       header: "Delete This Line Item?",
                       body: modalBody, 
                       showCloseButton: true,
                       cssClass: "mymodal",
                       closeCallback: function() {
                           alert('You closed the alert!');
                       }
                   })
               }                               
           });
    }
})