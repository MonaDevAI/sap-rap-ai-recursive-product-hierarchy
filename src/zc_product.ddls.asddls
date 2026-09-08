@Metadata.allowExtensions: true
define root view entity ZC_Product
  provider contract transactional_query
  as projection on ZI_Product_I
{
  key ProductID,
      ProductName,
      ProductType,

      @Semantics.imageUrl: true
      ProductImageUrl,

      _Hierarchy : redirected to composition child ZC_ProductHierarchy
}
