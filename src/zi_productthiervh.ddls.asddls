@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Product Hierarchy Value help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ProducttHierVH as select from ZI_ProductHierarchy_B
{

  @UI.hidden: true
  key ProductID,

  @EndUserText.label: 'Parent Node'
  @ObjectModel.text.element: [ 'HierValue' ]
  key HierID,

  @EndUserText.label: 'Hierarchy Type'
  @Search.defaultSearchElement: true
  HierType,

  @EndUserText.label: 'Hierarchy Value'
  @Search.defaultSearchElement: true
  HierValue,

  @EndUserText.label: 'Hierarchy Path'
  @Search.defaultSearchElement: true
  HierarchyPath

}
