/**
 * @File Name          : lookupSearchComponent.js
 * @Description        : 
 * @Author             : Jyoti Singh
 * @Group              : 
 * @Last Modified By   : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On   : 11-19-2020
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    10/10/2019   Jyoti Singh     Initial Version
**/
import { LightningElement, track, api } from 'lwc';


export default class LookupSearchComponent extends LightningElement {
    @api searchKey;
    @api label;
    

    handleChange(event){
        /* eslint-disable no-console */
        //console.log('Search Event Started ');
        const searchKey = event.target.value;
        /* eslint-disable no-console */
        event.preventDefault();
        const searchEvent = new CustomEvent(
            'change', 
            { 
                detail : searchKey
            }
        );
        this.dispatchEvent(searchEvent);
    }
}