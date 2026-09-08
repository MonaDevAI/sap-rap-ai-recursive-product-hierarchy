
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Product Hierarchy Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ProductHierarchy_I
  as select from ZI_ProductHierarchy_B
 association to parent ZI_Product_I          as _Product
   on  $projection.ProductID    = _Product.ProductID
  association [0..1] to ZI_ProductHierarchy_I as _Parent
    on  $projection.ParentHierID = _Parent.HierID
    and $projection.ProductID    = _Parent.ProductID
  association [0..*] to ZI_ProductHierarchy_I as _Children
    on  $projection.HierID       = _Children.ParentHierID
    and $projection.ProductID    = _Children.ProductID
{
  key HierID,
      ProductID,
      ParentHierID,
      HierType,
      HierValue,
      HierarchyPath,
      LastChangedAt,
      LocalLastChangedAt,
      _Product,
      _Parent,
      _Children
}


