({
	// Your renderer method overrides go here
    afterRender: function(component,event){
        var selectedPbeList = component.get("v.selectedPbeRecList");
        var currentPbe = component.get("v.pbeRec");
        
        for(var i in selectedPbeList){
            var selectedPbe =selectedPbeList[i];
            if(selectedPbe.Id == currentPbe.Id){
                if(!$A.util.isUndefinedOrNull(document.getElementById(currentPbe.Id))){
                    document.getElementById(currentPbe.Id).checked = true;
                    break;
                }
            }
        }
    }
})