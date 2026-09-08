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
    METHODS rejects_invalid_deployment FOR TESTING.
ENDCLASS.


CLASS ltc_product_hierarchy_ai IMPLEMENTATION.
  METHOD setup.
    CREATE OBJECT mo_cut
      EXPORTING
        iv_destination = 'ZPRODUCT_HIER_AI'
        iv_resource    = '/chat/completions'.
  ENDMETHOD.

  METHOD accepts_valid_recursive_tree.
    DATA ls_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
    DATA ls_node TYPE zcl_product_hierarchy_ai=>ty_node.
    DATA ls_result TYPE zcl_product_hierarchy_ai=>ty_result.

    ls_hierarchy-product_id = 'P100'.
    ls_hierarchy-product_name = 'Gala Apple'.

    ls_node-node_id = 'N1'.
    ls_node-hierarchy_type = 'L1'.
    ls_node-hierarchy_value = 'Food'.
    APPEND ls_node TO ls_hierarchy-nodes.

    CLEAR ls_node.
    ls_node-node_id = 'N2'.
    ls_node-parent_node_id = 'N1'.
    ls_node-hierarchy_type = 'L2'.
    ls_node-hierarchy_value = 'Fresh Produce'.
    APPEND ls_node TO ls_hierarchy-nodes.

    CLEAR ls_node.
    ls_node-node_id = 'N3'.
    ls_node-parent_node_id = 'N2'.
    ls_node-hierarchy_type = 'L3'.
    ls_node-hierarchy_value = 'Gala Apple'.
    APPEND ls_node TO ls_hierarchy-nodes.

    ls_result = mo_cut->validate_structure( ls_hierarchy ).

    cl_abap_unit_assert=>assert_true( ls_result-success ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 200 ).
  ENDMETHOD.

  METHOD rejects_orphan_parent.
    DATA ls_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
    DATA ls_node TYPE zcl_product_hierarchy_ai=>ty_node.
    DATA ls_result TYPE zcl_product_hierarchy_ai=>ty_result.

    ls_hierarchy-product_id = 'P100'.
    ls_node-node_id = 'N1'.
    ls_node-parent_node_id = 'MISSING'.
    ls_node-hierarchy_type = 'L2'.
    ls_node-hierarchy_value = 'Fresh Produce'.
    APPEND ls_node TO ls_hierarchy-nodes.

    ls_result = mo_cut->validate_structure( ls_hierarchy ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 422 ).
  ENDMETHOD.

  METHOD rejects_recursive_cycle.
    DATA ls_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
    DATA ls_node TYPE zcl_product_hierarchy_ai=>ty_node.
    DATA ls_result TYPE zcl_product_hierarchy_ai=>ty_result.

    ls_hierarchy-product_id = 'P100'.

    ls_node-node_id = 'N1'.
    ls_node-parent_node_id = 'N2'.
    ls_node-hierarchy_type = 'L1'.
    ls_node-hierarchy_value = 'Food'.
    APPEND ls_node TO ls_hierarchy-nodes.

    CLEAR ls_node.
    ls_node-node_id = 'N2'.
    ls_node-parent_node_id = 'N1'.
    ls_node-hierarchy_type = 'L2'.
    ls_node-hierarchy_value = 'Fresh Produce'.
    APPEND ls_node TO ls_hierarchy-nodes.

    ls_result = mo_cut->validate_structure( ls_hierarchy ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 422 ).
  ENDMETHOD.

  METHOD rejects_duplicate_node.
    DATA ls_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
    DATA ls_node TYPE zcl_product_hierarchy_ai=>ty_node.
    DATA ls_result TYPE zcl_product_hierarchy_ai=>ty_result.

    ls_hierarchy-product_id = 'P100'.

    ls_node-node_id = 'N1'.
    ls_node-hierarchy_type = 'L1'.
    ls_node-hierarchy_value = 'Food'.
    APPEND ls_node TO ls_hierarchy-nodes.

    CLEAR ls_node.
    ls_node-node_id = 'N1'.
    ls_node-hierarchy_type = 'L2'.
    ls_node-hierarchy_value = 'Produce'.
    APPEND ls_node TO ls_hierarchy-nodes.

    ls_result = mo_cut->validate_structure( ls_hierarchy ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 422 ).
  ENDMETHOD.

  METHOD rejects_insecure_ai_url.
    DATA lo_ai TYPE REF TO zcl_product_hierarchy_ai.
    DATA ls_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
    DATA ls_node TYPE zcl_product_hierarchy_ai=>ty_node.
    DATA ls_result TYPE zcl_product_hierarchy_ai=>ty_result.

    CREATE OBJECT lo_ai
      EXPORTING
        iv_url = 'http://example.invalid/chat/completions'.

    ls_hierarchy-product_id = 'P100'.
    ls_node-node_id = 'N1'.
    ls_node-hierarchy_type = 'L1'.
    ls_node-hierarchy_value = 'Food'.
    APPEND ls_node TO ls_hierarchy-nodes.

    ls_result = lo_ai->review_with_ai( ls_hierarchy ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 500 ).
  ENDMETHOD.

  METHOD rejects_invalid_deployment.
    DATA lo_ai TYPE REF TO zcl_product_hierarchy_ai.
    DATA ls_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
    DATA ls_node TYPE zcl_product_hierarchy_ai=>ty_node.
    DATA ls_result TYPE zcl_product_hierarchy_ai=>ty_result.

    CREATE OBJECT lo_ai
      EXPORTING
        iv_url =
          'https://example.invalid/deployments/{deployment}/chat/completions'
        iv_deployment = '../invalid'.

    ls_hierarchy-product_id = 'P100'.
    ls_node-node_id = 'N1'.
    ls_node-hierarchy_type = 'L1'.
    ls_node-hierarchy_value = 'Food'.
    APPEND ls_node TO ls_hierarchy-nodes.

    ls_result = lo_ai->review_with_ai( ls_hierarchy ).

    cl_abap_unit_assert=>assert_initial( ls_result-success ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 500 ).
  ENDMETHOD.
ENDCLASS.
