
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Product Hierarchy Base View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ProductHierarchy_B 
as select from zproduct_hier as Node

    association [0..1] to zproduct_hier as _Parent
      on  $projection.ProductID    = _Parent.productid
      and $projection.ParentHierID = _Parent.hierid
{
  key Node.hierid               as HierID,
      Node.productid            as ProductID,
      Node.parenthierid        as ParentHierID,
      Node.hiertype             as HierType,
      Node.hiervalue            as HierValue,
      Node.lastchangedat       as LastChangedAt,
      Node.locallastchangedat as LocalLastChangedAt,

      _Parent.hiervalue         as ParentHierValue,

      case
        when Node.parenthierid is initial
          then Node.hiervalue
        else concat_with_space(
               concat_with_space(
                 _Parent.hiervalue,
                 '→',
                 1
               ),
               Node.hiervalue,
               1
             )
      end                        as HierarchyPath,

      _Parent
}
