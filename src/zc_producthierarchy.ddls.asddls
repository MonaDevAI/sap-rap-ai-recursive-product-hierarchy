@Metadata.allowExtensions: true

define view entity ZC_ProductHierarchy
  as projection on ZI_ProductHierarchy_I
{
  @ObjectModel.text.element: [ 'HierValue' ]
  key HierID,
      ProductID,

      @ObjectModel.text.element: [ 'ParentHierValue' ]
      ParentHierID,
      _Parent.HierValue as ParentHierValue,

      HierType,
      HierValue,
      HierarchyPath,

      _Product  : redirected to parent ZC_Product,
      _Parent   : redirected to ZC_ProductHierarchy,
      _Children : redirected to ZC_ProductHierarchy
}
