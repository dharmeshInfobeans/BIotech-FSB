({
    doInit : function(component, event, helper) {
        console.log("ZZZ InAddProductComp-->C-->doInit_M !!");
        helper.showSpinner(component);
        helper.getExistingOppProds(component, event);
        helper.getColumnDefinitions(component, event);
        helper.getAllProducts(component, event);
    },
    onDeleteConfirmation : function(component, event, helper) {
        
    },
    modalHandlerOnYes : function(component, event, helper) {
        helper.showSpinner(component);
        helper.deleteOppProduct(component,event);
    },
    handleOpenModal: function(component, event, helper) {
        //For Display Modal, Set the "openModal" attribute to "true"
        //component.set("v.openModal", true);
        helper.openModal(component, event);
    },
    
    handleCloseModal: function(component, event, helper) {
        //For Close Modal, Set the "openModal" attribute to "fasle"  
        //component.set("v.openModal", false);
        helper.closeModal(component, event);
    },
    onSave : function(component, event, helper) {
        helper.showSpinner(component);
        helper.saveOppProducts(component, event);
    },
    removeAddedProduct : function(component,event,helper){
        
        var oppId = event.currentTarget.dataset.oppid;
        var oppProdId = event.currentTarget.dataset.opprodid;
        
        console.log('OPPID-->'+oppId);
        console.log('OPP Product ID-->'+ oppProdId);
        
        var prodId = event.target.id;
        console.log('ID--->'+prodId);
        
        if(!$A.util.isEmpty(oppId) && !$A.util.isEmpty(oppProdId)){
            component.set("v.oppProductId", oppProdId); //setting oppProdId
            component.set("v.productId", prodId); //setting ProdId
            console.log("ZZZ InAddProductComp-->C-->removeAddedProduct_M--> oppPRODUCT ID-->"+JSON.stringify(component.get("v.oppProductId")));
            helper.openModal(component,event);
            // helper.deleteOppProduct(component,event,oppId,oppProdId);
        }else{
			helper.removeAddedProductHelper(component,event,prodId);
        }        
    }, 
    handleRowAction : function(component,event,helper){
        console.log("ZZZ InAddProductComp-->C-->handleRowAction_M !!");
        
        //If Check box is enabled than below will give the selected column ID
        //var editedRecords =  component.find("prodDataTable").get("v.selectedRows");
        //console.log("Selected Rec-->"+JSON.stringify(editedRecords));
        //var totalRecordEdited = editedRecords.length;    
        //console.log("Selected Rec length-->"+JSON.stringify(totalRecordEdited));
        
        //Gives All Selected Row Details
        //var slrow2 = component.find("prodDataTable").getSelectedRows();
        //console.log("New Select-->"+JSON.stringify(slrow2));
        
        var row = event.getParam('row');
        console.log("ZZZ InAddProductComp-->C-->handleRowAction_M-->Select ROW Det-->"+JSON.stringify(row));
        helper.removeProductFromLstAndAdd(component, event,row);
        
        
    },
    handleSearch : function(component,event,helper){
        var searchKey = component.get("v.searchString");
        if(searchKey.length > 1 && !$A.util.isEmpty(searchKey)){
            helper.showSpinner(component);
            helper.getProductBySearchString(component, event,searchKey);
        }else{
            helper.showSpinner(component);
            helper.getAllProducts(component, event);
        }
        
    },
    rowSelectionHandler : function(component,event,helper){
        
    },
})