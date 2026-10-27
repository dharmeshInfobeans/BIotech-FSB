/**
 * Validation message constants for the Event Planner Create Event component
 */

export const VALIDATION_MESSAGES = {
    REQUIRED_FIELDS: 'Please fill the required field',
    PHAKIC_PRODUCTS_ONLY: 'Please select only Phakic Products',
    LEVEL_TYPE_REQUIRED: 'please fill the Level type for Phakic training type',
    EVENT_CREATED: 'Event Created Successfully',
    CE_CIS_NOT_APPROVED: 'Please approved CE-CIS and Phakic rating before creating the events',
    ADDRESS_NOT_APPROVED: 'Please approved address before creating the events',
    CE_CIS_PHAKIC_NOT_APPROVED: 'Please approved ce-cis and phakic rating before creating the events',
    ALL_NOT_APPROVED: 'Please approved address and CE-CIS and phakic rating before creating the events',
    COMPENSATION_OFF_SELECT_ONE: 'Only one row can be selected at a time.',
    BD_PLAN_LINKED: 'BD Plan Linked Successfully',
    SUB_CALL_TYPE_REQUIRED: 'Sub Call type is required'
};

export const RESPONSE_CODES = {
    SUCCESS: 'Success',
    ERROR: 'error',
    ADDRESS: 'Address',
    CECIS: 'CECIS',
    REJECT: 'reject'
};