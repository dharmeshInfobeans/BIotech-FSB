({
    getCodes : function(component, event, helper) {
        
        var subProduct = component.get('v.subProductItem');
        var selectedModel = component.find('modelSelect').get("v.value");
        subProduct.ModelTxt = selectedModel;
        
        
        
        
        var modelsWithPowerRange = component.get('v.modelsWithPowerRange');
        
        for(var i =0; i < modelsWithPowerRange.length; i++) {
            if(selectedModel == modelsWithPowerRange[i].Text_Name__c){
                subProduct.PowerRange = modelsWithPowerRange[i].powerRange;
                subProduct.axisAngle =  modelsWithPowerRange[i].axisAngle;
                subProduct.cylindricalPower = modelsWithPowerRange[i].cylindricalPower;
                var powerOpts = [];
                for(var i =0; i < subProduct.PowerRange.length; i++){
                    if(i==0){
                        powerOpts.push({ "class": "optionClass", label: subProduct.PowerRange[i].toString(), value: subProduct.PowerRange[i], selected: "true" });
                        
                        
                    }else{
                        powerOpts.push({ "class": "optionClass", label: subProduct.PowerRange[i].toString(), value: subProduct.PowerRange[i]});
                    }
                }
                
                var axisAngleOpts = [];  
                for(var i =0; i < subProduct.axisAngle.length; i++){
                    if(i==0){
                        axisAngleOpts.push({ "class": "optionClass", label: subProduct.axisAngle[i].toString(), value: subProduct.axisAngle[i], selected: "true" });
                    }else{
                        axisAngleOpts.push({ "class": "optionClass", label: subProduct.axisAngle[i].toString(), value: subProduct.axisAngle[i]});
                    }
                }
                
                
                var CylindricalPowerOpts = [];
                for(var i =0; i < subProduct.cylindricalPower.length; i++){
                    if(i==0){
                        CylindricalPowerOpts.push({ "class": "optionClass", label: subProduct.cylindricalPower[i].toString(), value: subProduct.cylindricalPower[i], selected: "true" });
                    }else{
                        CylindricalPowerOpts.push({ "class": "optionClass", label: subProduct.cylindricalPower[i].toString(), value: subProduct.cylindricalPower[i]});
                    }
                }
                
                component.find("SphericalPower").set("v.options", powerOpts);
                component.find("AxisAngle").set("v.options", axisAngleOpts);
                component.find("CylindricalPower").set("v.options", CylindricalPowerOpts);
                
                var selectedSPower =  component.find('SphericalPower').get('v.value');
                var angleSelected =  component.find('AxisAngle').get('v.value');
                var selectedCylendricalPower =  component.find('CylindricalPower').get('v.value');
                subProduct.SelectedCylendricalPower = selectedCylendricalPower;
                subProduct.selectedaxisAngle = angleSelected;
                subProduct.SelectedPower = selectedSPower; 
                
                
                break;
            }
        }
        
        component.set('v.subProductItem',subProduct);
    },
    
    doInit : function(component, event, helper){
        var subItem = component.get('v.subProductItem');
        var modelsWithCodes = component.get('v.modelsWithCodes');
        var modelsWithPowerRange = component.get('v.modelsWithPowerRange');
        console.log('Order product : ',JSON.stringify(subItem));
        if(modelsWithPowerRange.length ==0)
            return;
        
        var models = [];  
        for(var i =0; i < modelsWithPowerRange.length; i++) {
            models.push(modelsWithPowerRange[i].Text_Name__c);
        }
        
        component.set('v.models', models);
        
        var selectedModel;
        
        //Get Codes and set on of them as default value
        if(typeof subItem.ModelTxt!=='undefined' && subItem.ModelTxt!='')
            selectedModel = subItem.ModelTxt;
        else
            selectedModel = models[0];        
        
        
        
        var modelsWithPowerRange = component.get('v.modelsWithPowerRange');
        console.log('Models with power range : ',modelsWithPowerRange.length);
        for(var ik =0; ik < modelsWithPowerRange.length; ik++) {
            console.log('Models with power range : ',selectedModel+'------- : ',modelsWithPowerRange[ik]);
            if(selectedModel == modelsWithPowerRange[ik].Text_Name__c){        
                subItem.ModelTxt = selectedModel;
                subItem.PowerRange = modelsWithPowerRange[ik].powerRange;
                subItem.axisAngle = modelsWithPowerRange[ik].axisAngle;
                subItem.cylindricalPower = modelsWithPowerRange[ik].cylindricalPower;
                
                var powerOpts = [];
                for(var i =0; i < subItem.PowerRange.length; i++){
                    
                    if(i==0 && subItem.RecordId=='' && (subItem.SelectedPower==''||subItem.SelectedPower==undefined )){
                       // var SelectedPower; 
                        subItem.SelectedPower = subItem.PowerRange[i];
                        powerOpts.push({ "class": "optionClass", label: subItem.PowerRange[i], value: subItem.PowerRange[i], selected: "true" });
                        
                    }else{
                        powerOpts.push({ "class": "optionClass", label: subItem.PowerRange[i], value: subItem.PowerRange[i]});
                    }
                    
                }
                
                var angleOpts = [];
                for(var i =0; i < subItem.axisAngle.length; i++){
                    if(i==0 && subItem.RecordId=='' && (subItem.selectedaxisAngle=='' ||subItem.selectedaxisAngle==undefined )){
                     	subItem.selectedaxisAngle = subItem.axisAngle[i];
                        angleOpts.push({ "class": "optionClass", label: subItem.axisAngle[i], value: subItem.axisAngle[i], selected: "true" });
                    }else{
                        angleOpts.push({ "class": "optionClass", label: subItem.axisAngle[i], value: subItem.axisAngle[i]});
                    }
                }
                
                var cyPowOpts = [];
                for(var i =0; i < subItem.cylindricalPower.length; i++){
                    if(i==0 && subItem.RecordId=='' && (subItem.SelectedCylendricalPower==''||subItem.SelectedCylendricalPower==undefined)){
                        subItem.SelectedCylendricalPower = subItem.cylindricalPower[i];
                        cyPowOpts.push({ "class": "optionClass", label: subItem.cylindricalPower[i], value: subItem.cylindricalPower[i], selected: "true" });
                    }else{
                        cyPowOpts.push({ "class": "optionClass", label: subItem.cylindricalPower[i], value: subItem.cylindricalPower[i]});
                    }
                } 
                
                component.find("SphericalPower").set("v.options", powerOpts);
                component.find("CylindricalPower").set("v.options", cyPowOpts);
                component.find("AxisAngle").set("v.options", angleOpts);
                
                
                if(typeof subItem.SelectedPower!=='undefined' && subItem.SelectedPower!=''){
                    if( powerOpts !=undefined && powerOpts.length >0){
                        powerOpts.forEach(function(Item){
                            
                            if(Item.value == subItem.SelectedPower){
                                Item.selected = true;
                            }
                        });
                        
                    }
                }                
                
                if(typeof subItem.SelectedCylendricalPower!=='undefined' && subItem.SelectedCylendricalPower!=''){
                    // component.find('CylindricalPower').set('v.value', subItem.SelectedCylendricalPower);
                    if( cyPowOpts !=undefined && cyPowOpts.length >0){
                        cyPowOpts.forEach(function(Item){
                            
                            if(Item.value == subItem.SelectedCylendricalPower){
                                Item.selected = true;
                            }
                        });
                        
                    }        
                }
                
                
                if(typeof subItem.selectedaxisAngle!=='undefined' && subItem.selectedaxisAngle!=''){
                    //  component.find('AxisAngle').set('v.value', subItem.selectedaxisAngle);
                    if( angleOpts !=undefined && angleOpts.length >0){
                        angleOpts.forEach(function(Item){                   
                            if(Item.value == subItem.selectedaxisAngle){
                                Item.selected = true;
                            }
                        });
                        
                    }  
                }   
                
                component.find('modelSelect').set("v.value",subItem.ModelTxt);
                subItem.SelectedPower = subItem.SelectedPower;
                component.set('v.subProductItem',subItem);
                
                var selectedSphericalPower = component.find('SphericalPower').get('v.value');
                var selectedCylendricalPower =  component.find('CylindricalPower').get('v.value');
                var subProduct = component.get('v.subProductItem');
              //  subProduct.SelectedCylendricalPower = selectedCylendricalPower;
               // subProduct.SelectedPower = selectedSphericalPower;
                component.set('v.subProductItem', subProduct);   
                
                var angleSelected =  component.find('AxisAngle').get('v.value');
                var subProduct = component.get('v.subProductItem');
              //  subProduct.selectedaxisAngle = angleSelected;        
                component.set('v.subProductItem', subProduct);
                console.log('reached here');
            }
        }
    },
    
    onModelInit : function(component, event, helper){
        helper.setModelsAndCodes(component);    
    },
    
    powerChange : function(component, event, helper){
        var selectedSPower =  component.find('SphericalPower').get('v.value');
        var subProduct = component.get('v.subProductItem');
        subProduct.SelectedPower = selectedSPower !== '' ? selectedSPower : selectedSPower;
        component.set('v.subProductItem', subProduct);
    },
    cylendriclPowChange : function(component, event, helper){
        var selectedCylendricalPower =  component.find('CylindricalPower').get('v.value');
        var subProduct = component.get('v.subProductItem');
        subProduct.SelectedCylendricalPower = selectedCylendricalPower !== '' ? selectedCylendricalPower : null;
        component.set('v.subProductItem', subProduct);
    },
    axisAngleChange : function(component, event, helper){
        
        var angleSelected =  component.find('AxisAngle').get('v.value');
        var subProduct = component.get('v.subProductItem');
        subProduct.selectedaxisAngle = angleSelected !== '' ? angleSelected : null;
        component.set('v.subProductItem', subProduct);
    },
    onQuantityChange : function(component, event, helper){
        var subProductItem = component.get('v.subProductItem');
        console.log('subProductItem : ',subProductItem);
        if(subProductItem.FocQuantity == undefined){
            subProductItem.FocQuantity = 0;
        }
        subProductItem.Quantity = event.getSource().get('v.value');
     //   subProductItem.SubTotalPrice = subProductItem.SalesPrice * (subProductItem.Quantity - subProductItem.FocQuantity);//Commented codeP
          subProductItem.SubTotalPrice = subProductItem.SalesPrice * subProductItem.Quantity;
            
        subProductItem.totalQuantity=(subProductItem.FocQuantity==undefined || subProductItem.FocQuantity==0 || subProductItem.FocQuantity==null || subProductItem.FocQuantity=='' || subProductItem.FocQuantity==NaN) && (subProductItem.Quantity==undefined || subProductItem.Quantity==0 || subProductItem.Quantity==null || subProductItem.Quantity=='' || subProductItem.Quantity==NaN) ? 0 : (parseInt(subProductItem.Quantity) + parseInt(subProductItem.FocQuantity)); //code add
        if(isNaN(subProductItem.totalQuantity)){
            subProductItem.totalQuantity=0;
        }
        
        if(subProductItem.Discount > 0)
            subProductItem.TotalPrice = subProductItem.SubTotalPrice -(subProductItem.SubTotalPrice * subProductItem.Discount/100);
        else
            subProductItem.TotalPrice = subProductItem.SubTotalPrice;
        
        
        component.set('v.subProductItem', subProductItem);
        
        helper.onProductItemChange(component, event, helper);
        helper.calculateFOCquantity(component, subProductItem);
    },
    
    onFocQuantityChange : function(component, event, helper){
        var subProductItem = component.get('v.subProductItem');
        subProductItem.FocQuantity = event.getSource().get('v.value');
       // subProductItem.SubTotalPrice = subProductItem.SalesPrice * (subProductItem.Quantity - subProductItem.FocQuantity);//Commented Code//P
        
         subProductItem.SubTotalPrice = subProductItem.SalesPrice * subProductItem.Quantity;
        
        subProductItem.totalQuantity=(subProductItem.FocQuantity==undefined || subProductItem.FocQuantity==0 || subProductItem.FocQuantity==null || subProductItem.FocQuantity=='' || subProductItem.FocQuantity==NaN) && (subProductItem.Quantity==undefined || subProductItem.Quantity==0 || subProductItem.Quantity==null || subProductItem.Quantity=='' || subProductItem.Quantity==NaN) ? 0 : (parseInt(subProductItem.Quantity) + parseInt(subProductItem.FocQuantity)); //code add
        if(isNaN(subProductItem.totalQuantity)){
            subProductItem.totalQuantity=0;
        }
        if(subProductItem.Discount > 0)
            subProductItem.TotalPrice = subProductItem.SubTotalPrice -(subProductItem.SubTotalPrice * subProductItem.Discount/100);
        else
            subProductItem.TotalPrice = subProductItem.SubTotalPrice;
        
        
        component.set('v.subProductItem', subProductItem);
        
        helper.onProductItemChange(component, event, helper);
    },
    
    
    onDiscountChange : function(component, event, helper){
        helper.onProductItemChange(component, event, helper);
    },
    
    deleteSubProduct : function(component, event, helper){
        var subProdDeleteEvnt = component.getEvent("subProdDeleteEvnt");  
        subProdDeleteEvnt.setParams({
            "orderProduct" : component.get('v.subProductItem'),
            "isDelete" : true
        });
        subProdDeleteEvnt.fire();        
    }
})