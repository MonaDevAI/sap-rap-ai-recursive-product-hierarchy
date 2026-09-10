CLASS lhc_Product DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Product RESULT result.

    METHODS validateHierarchy FOR MODIFY
      IMPORTING keys FOR ACTION Product~validateHierarchy.

    METHODS reviewHierarchyWithAI FOR MODIFY
      IMPORTING keys FOR ACTION Product~reviewHierarchyWithAI.

ENDCLASS.

CLASS lhc_Product IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD validateHierarchy.
    READ ENTITIES OF zi_product_i IN LOCAL MODE
      ENTITY Product
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_products)
      ENTITY Product BY \_Hierarchy
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_hierarchy).

    LOOP AT lt_products INTO DATA(ls_product).
      DATA ls_ai_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
      DATA ls_ai_node TYPE zcl_product_hierarchy_ai=>ty_node.
      DATA ls_ai_result TYPE zcl_product_hierarchy_ai=>ty_result.

      ls_ai_hierarchy-product_id = ls_product-ProductID.
      ls_ai_hierarchy-product_name = ls_product-ProductName.
      ls_ai_hierarchy-product_type = ls_product-ProductType.

      LOOP AT lt_hierarchy INTO DATA(ls_hierarchy)
        WHERE ProductID = ls_product-ProductID.
        CLEAR ls_ai_node.
        ls_ai_node-node_id = |{ ls_hierarchy-HierID }|.
        IF ls_hierarchy-ParentHierID IS NOT INITIAL.
          ls_ai_node-parent_node_id = |{ ls_hierarchy-ParentHierID }|.
        ENDIF.
        ls_ai_node-hierarchy_type = ls_hierarchy-HierType.
        ls_ai_node-hierarchy_value = ls_hierarchy-HierValue.
        APPEND ls_ai_node TO ls_ai_hierarchy-nodes.
      ENDLOOP.

      DATA(lo_ai) = NEW zcl_product_hierarchy_ai( ).
      ls_ai_result = lo_ai->validate_structure( ls_ai_hierarchy ).

      DATA(lv_severity) = if_abap_behv_message=>severity-information.
      DATA(lv_message) = ls_ai_result-content.
      IF ls_ai_result-success <> abap_true.
        lv_severity = if_abap_behv_message=>severity-error.
        lv_message = ls_ai_result-error_message.
      ENDIF.

      APPEND INITIAL LINE TO reported-product
        ASSIGNING FIELD-SYMBOL(<ls_validate_message>).
      <ls_validate_message>-%tky = ls_product-%tky.
      <ls_validate_message>-%msg = new_message_with_text(
        severity = lv_severity
        text     = lv_message ).
    ENDLOOP.
  ENDMETHOD.

  METHOD reviewHierarchyWithAI.
    READ ENTITIES OF zi_product_i IN LOCAL MODE
      ENTITY Product
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_products)
      ENTITY Product BY \_Hierarchy
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_hierarchy).

    SELECT SINGLE low
      FROM tvarvc
      INTO @DATA(lv_ai_url)
      WHERE name = 'ZPRODUCT_HIER_AI_URL'
        AND type = 'P'.

    LOOP AT lt_products INTO DATA(ls_product).
      DATA ls_ai_hierarchy TYPE zcl_product_hierarchy_ai=>ty_hierarchy.
      DATA ls_ai_node TYPE zcl_product_hierarchy_ai=>ty_node.
      DATA ls_ai_result TYPE zcl_product_hierarchy_ai=>ty_result.

      ls_ai_hierarchy-product_id = ls_product-ProductID.
      ls_ai_hierarchy-product_name = ls_product-ProductName.
      ls_ai_hierarchy-product_type = ls_product-ProductType.

      LOOP AT lt_hierarchy INTO DATA(ls_hierarchy)
        WHERE ProductID = ls_product-ProductID.
        CLEAR ls_ai_node.
        ls_ai_node-node_id = |{ ls_hierarchy-HierID }|.
        IF ls_hierarchy-ParentHierID IS NOT INITIAL.
          ls_ai_node-parent_node_id = |{ ls_hierarchy-ParentHierID }|.
        ENDIF.
        ls_ai_node-hierarchy_type = ls_hierarchy-HierType.
        ls_ai_node-hierarchy_value = ls_hierarchy-HierValue.
        APPEND ls_ai_node TO ls_ai_hierarchy-nodes.
      ENDLOOP.

      DATA(lo_ai) = NEW zcl_product_hierarchy_ai(
        iv_destination = 'ZPRODUCT_HIER_AI'
        iv_resource    = '/chat/completions'
        iv_url         = CONV string( lv_ai_url ) ).

      ls_ai_result = lo_ai->review_with_ai( ls_ai_hierarchy ).

      DATA(lv_severity) = if_abap_behv_message=>severity-information.
      DATA(lv_message) = ls_ai_result-content.
      IF ls_ai_result-success <> abap_true.
        lv_severity = if_abap_behv_message=>severity-error.
        lv_message = ls_ai_result-error_message.
      ELSEIF ls_ai_result-review-has_concern = abap_true.
        lv_severity = if_abap_behv_message=>severity-warning.
      ENDIF.

      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf
        IN lv_message WITH space.
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
        IN lv_message WITH space.

      DATA lv_offset TYPE i.
      DATA lv_chunk_length TYPE i.
      DATA lv_remaining TYPE i.
      DATA lv_message_chunk TYPE string.

      WHILE lv_offset < strlen( lv_message ).
        lv_remaining = strlen( lv_message ) - lv_offset.
        lv_chunk_length = 50.
        IF lv_remaining < lv_chunk_length.
          lv_chunk_length = lv_remaining.
        ENDIF.

        lv_message_chunk = lv_message+lv_offset(lv_chunk_length).

        APPEND INITIAL LINE TO reported-product
          ASSIGNING FIELD-SYMBOL(<ls_ai_message>).
        <ls_ai_message>-%tky = ls_product-%tky.
        <ls_ai_message>-%msg = new_message_with_text(
          severity = lv_severity
          text     = lv_message_chunk ).

        lv_offset = lv_offset + lv_chunk_length.
      ENDWHILE.

      IF lv_message IS INITIAL.
        APPEND INITIAL LINE TO reported-product
          ASSIGNING FIELD-SYMBOL(<ls_empty_ai_message>).
        <ls_empty_ai_message>-%tky = ls_product-%tky.
        <ls_empty_ai_message>-%msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'AI service returned an empty response.' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
