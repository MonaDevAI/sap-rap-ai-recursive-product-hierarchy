*&---------------------------------------------------------------------*
*& Report ZR_PRODUCT_RECURSIVE_DEMO
*&---------------------------------------------------------------------*
*& Demonstrates recursive hierarchy data for RAP entity ZC_PRODUCT.
*& Loads food items (Gala Apple, Milk) and an electronics item.
*&---------------------------------------------------------------------*
REPORT zr_product_recursive_demo.

PARAMETERS p_reset TYPE abap_bool AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.
  IF p_reset = abap_true.
    SELECT SINGLE @abap_true
      FROM zproduct_hdr_d
      WHERE productid LIKE 'DEMO_%'
      INTO @DATA(lv_demo_draft_exists).

    IF lv_demo_draft_exists = abap_true.
      WRITE: / 'Reset cancelled: discard active DEMO_% drafts before resetting demo data.'.
      RETURN.
    ENDIF.
  ENDIF.

  DATA lv_ts TYPE timestampl.
  GET TIME STAMP FIELD lv_ts.

  DATA lt_products TYPE STANDARD TABLE OF zproduct_hdr WITH EMPTY KEY.
  DATA lt_hier     TYPE STANDARD TABLE OF zproduct_hier WITH EMPTY KEY.

  lt_products = VALUE #(
    (  productid = 'DEMO_GALA_APPLE_1KG' productname = 'Gala Apple 1kg'      producttype = 'FRUIT' productimageurl = 'https://images.unsplash.com/photo-1567306226416-28f0efdc88ce?auto=format&fit=crop&w=120&h=120' )
    (  productid = 'DEMO_MILK_TONED_1L'  productname = 'Toned Milk 1L'       producttype = 'MILK'  productimageurl = 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=120&h=120' )
    (  productid = 'DEMO_HEADPHONE_BT'   productname = 'Bluetooth Headphone' producttype = 'ELEC'  productimageurl = 'https://images.unsplash.com/photo-1546435770-a3e426bf472b?auto=format&fit=crop&w=120&h=120' )
  ).

  TRY.
      DATA(lv_a_l1) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_a_l2) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_a_l3) = cl_system_uuid=>create_uuid_x16_static( ).

      DATA(lv_m_l1) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_m_l2) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_m_l3) = cl_system_uuid=>create_uuid_x16_static( ).

      DATA(lv_e_l1) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_e_l2) = cl_system_uuid=>create_uuid_x16_static( ).
      DATA(lv_e_l3) = cl_system_uuid=>create_uuid_x16_static( ).

      lt_hier = VALUE #(
        (  hierid = lv_a_l1 productid = 'DEMO_GALA_APPLE_1KG' hiertype = 'L1' hiervalue = 'Food' )
        (  hierid = lv_a_l2 productid = 'DEMO_GALA_APPLE_1KG' parenthierid = lv_a_l1 hiertype = 'L2' hiervalue = 'Fresh Produce' )
        (  hierid = lv_a_l3 productid = 'DEMO_GALA_APPLE_1KG' parenthierid = lv_a_l2 hiertype = 'L3' hiervalue = 'Gala Apple' )

        (  hierid = lv_m_l1 productid = 'DEMO_MILK_TONED_1L' hiertype = 'L1' hiervalue = 'Food' )
        (  hierid = lv_m_l2 productid = 'DEMO_MILK_TONED_1L' parenthierid = lv_m_l1 hiertype = 'L2' hiervalue = 'Dairy' )
        (  hierid = lv_m_l3 productid = 'DEMO_MILK_TONED_1L' parenthierid = lv_m_l2 hiertype = 'L3' hiervalue = 'Milk' )

        (  hierid = lv_e_l1 productid = 'DEMO_HEADPHONE_BT' hiertype = 'L1' hiervalue = 'Electronics' )
        (  hierid = lv_e_l2 productid = 'DEMO_HEADPHONE_BT' parenthierid = lv_e_l1 hiertype = 'L2' hiervalue = 'Audio' )
        (  hierid = lv_e_l3 productid = 'DEMO_HEADPHONE_BT' parenthierid = lv_e_l2 hiertype = 'L3' hiervalue = 'Headphones' )
      ).
    CATCH cx_uuid_error INTO DATA(lx_uuid).
      WRITE: / 'UUID generation failed:', lx_uuid->get_text( ).
      RETURN.
  ENDTRY.

  LOOP AT lt_products ASSIGNING FIELD-SYMBOL(<ls_product>).
    <ls_product>-lastchangedat = lv_ts.
    <ls_product>-locallastchangedat = lv_ts.
  ENDLOOP.

  LOOP AT lt_hier ASSIGNING FIELD-SYMBOL(<ls_hier>).
    <ls_hier>-lastchangedat = lv_ts.
    <ls_hier>-locallastchangedat = lv_ts.
  ENDLOOP.

  IF p_reset = abap_true.
    DELETE FROM zproduct_hier WHERE productid LIKE 'DEMO_%'.
    DELETE FROM zproduct_hdr  WHERE productid LIKE 'DEMO_%'.
  ENDIF.

  INSERT zproduct_hdr FROM TABLE @lt_products ACCEPTING DUPLICATE KEYS.
  DATA(lv_hdr_ins) = sy-dbcnt.

  INSERT zproduct_hier FROM TABLE @lt_hier ACCEPTING DUPLICATE KEYS.
  DATA(lv_hier_ins) = sy-dbcnt.

  COMMIT WORK.

  WRITE: / |Inserted products: { lv_hdr_ins }, hierarchy nodes: { lv_hier_ins }.|.
