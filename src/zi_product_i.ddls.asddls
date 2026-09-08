@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_Product_I
  as select from ZI_Product_B
  composition [0..*] of ZI_ProductHierarchy_I as _Hierarchy
  association [0..*] to ZI_Product_B           as _ProductType
    on $projection.ProductType = _ProductType.ProductType
{
  key ProductID,
      ProductName,

      @ObjectModel.foreignKey.association: '_ProductType'
      ProductType,

      ProductImageUrl,
      LastChangedAt,
      LocalLastChangedAt,
      _Hierarchy,
      _ProductType
}

