
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Product Base View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_Product_B as select from zproduct_hdr as Header
{
  key Header.productid          as ProductID,
      Header.productname        as ProductName,
      Header.producttype        as ProductType,
      @Semantics.imageUrl: true
      Header.productimageurl    as ProductImageUrl,
      Header.lastchangedat      as LastChangedAt,
      Header.locallastchangedat as LocalLastChangedAt
}
