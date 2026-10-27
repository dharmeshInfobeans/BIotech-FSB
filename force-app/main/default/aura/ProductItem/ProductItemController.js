({
	selectItem : function(component, event, helper) {
        var pbeRec = component.get('v.pbeRec');
       	 var chkBoxId = 'chk_'+pbeRec.Id;
        console.log(document.getElementById(chkBoxId).checked);
        if(document.getElementById(chkBoxId).checked == false){
            var removeSelectItemEvent = component.getEvent("removeProductEvent");
            removeSelectItemEvent.setParams({"selectedPbe": component.get('v.pbeRec')});
            removeSelectItemEvent.fire();    
        } else {
            var selectItemEvent = component.getEvent("selectProductEvent");
            selectItemEvent.setParams({"selectedPbe": component.get('v.pbeRec')});
            selectItemEvent.fire();    
            //document.getElementById(pbeRec.Id).checked = true;
        }
	},
    
    deSelectItem : function(component, event, helper) {
        var params = event.getParam('selectedId');
        var elementId = document.getElementById('selectedId');
        if( elementId !== null)
			elementId.checked = false;
	},
    
   
    
})