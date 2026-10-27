<aura:application extends="force:slds" >
    <aura:attribute name="id" type="String" />
    
    <div class="slds-backdrop slds-backdrop_open"></div>
    
    <c:SubmitCIS approvalMode="true" readOnly="true" headerId="{!v.id}"/>
</aura:application>