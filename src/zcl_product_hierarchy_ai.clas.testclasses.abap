CLASS ltc_product_hierarchy_ai DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_product_hierarchy_ai.

    METHODS setup.
    METHODS accepts_valid_recursive_tree FOR TESTING.
    METHODS rejects_orphan_parent FOR TESTING.
    METHODS rejects_recursive_cycle FOR TESTING.
    METHODS rejects_duplicate_node FOR TESTING.
    METHODS rejects_insecure_ai_url FOR TESTING.
ENDCLASS.


CLASS ltc_product_hierarchy_ai IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW zcl_product_hierarchy_ai(
      iv_destination = 'ZPRODUCT_HIER_AI'
      iv_resource    = '/chat/completions' ).
  ENDMETHOD.

  METHOD accepts_valid_recursive_tree.
    DATA(ls_result) = mo_cut->validate_structure(
      VALUE #(
        product_id   = 'P100'
        product_name = 'Gala Apple'
        nodes = VALUE #(
          ( node_id = 'N1' hierarchy_type = 'L1' hierarchy_value = 'Food' )
          ( node_id = 'N2' parent_node_id = 'N1'
            hierarchy_type = 'L2' hierarchy_value = 'Fresh Produce' )
          ( node_id = 'N3' parent_node_id = 'N2'
            hierarchy_type = 'L3' hierarchy_value = 'Gala Apple' ) ) ) ).

    cl_abap_unit_assert=>assert_true( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code exp = 200 ).
  ENDMETHOD.

  METHOD rejects_orphan_parent.
    DATA(ls_result) = mo_cut->validate_structure(
      VALUE #(
        product_id = 'P100'
        nodes = VALUE #(
          ( node_id = 'N1' parent_node_id = 'MISSING'
            hierarchy_type = 'L2' hierarchy_value = 'Fresh Produce' ) ) ) ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code exp = 422 ).
  ENDMETHOD.

  METHOD rejects_recursive_cycle.
    DATA(ls_result) = mo_cut->validate_structure(
      VALUE #(
        product_id = 'P100'
        nodes = VALUE #(
          ( node_id = 'N1' parent_node_id = 'N2'
            hierarchy_type = 'L1' hierarchy_value = 'Food' )
          ( node_id = 'N2' parent_node_id = 'N1'
            hierarchy_type = 'L2' hierarchy_value = 'Fresh Produce' ) ) ) ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code exp = 422 ).
  ENDMETHOD.

  METHOD rejects_duplicate_node.
    DATA(ls_result) = mo_cut->validate_structure(
      VALUE #(
        product_id = 'P100'
        nodes = VALUE #(
          ( node_id = 'N1' hierarchy_type = 'L1' hierarchy_value = 'Food' )
          ( node_id = 'N1' hierarchy_type = 'L2' hierarchy_value = 'Produce' ) ) ) ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code exp = 422 ).
  ENDMETHOD.

  METHOD rejects_insecure_ai_url.
    DATA(lo_ai) = NEW zcl_product_hierarchy_ai(
      iv_url = 'http://example.invalid/chat/completions' ).

    DATA(ls_result) = lo_ai->review_with_ai(
      VALUE #(
        product_id = 'P100'
        nodes = VALUE #(
          ( node_id = 'N1' hierarchy_type = 'L1' hierarchy_value = 'Food' ) ) ) ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code exp = 500 ).
  ENDMETHOD.
ENDCLASS.
